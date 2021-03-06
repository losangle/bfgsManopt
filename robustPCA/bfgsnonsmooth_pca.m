function [stats, finalX] = bfgsnonsmooth_pca(problem, x, options)
    
    timetic = tic();
    M = problem.M;

    if ~exist('x','var')
        xCur = M.rand();
    else 
        xCur = x;
    end
    
    localdefaults.minstepsize = 1e-50;
    localdefaults.maxiter = 10000;
    localdefaults.tolgradnorm = 1e-1;  %iterimgradnorm that is used during discrepency < maxdiscrepency
    localdefaults.finalgradnorm = 1e-7;
    localdefaults.memory = 10;
    localdefaults.c1 = 0.0; 
    localdefaults.c2 = 0.5;
    localdefaults.discrepency = 1e-3;
    localdefaults.discrepencydownscalefactor = 1e-1; 
    localdefaults.maxdiscrepency = 1e-13;
    localdefaults.lsmaxcounter = 50;
    localdefaults.useProgressiveTol = 0;
    
    % Merge global and local defaults, then merge w/ user options, if any.
    localdefaults = mergeOptions(getGlobalDefaults(), localdefaults);
    if ~exist('options', 'var') || isempty(options)
        options = struct();
    end
    options = mergeOptions(localdefaults, options);
   
    if (options.useProgressiveTol == 1)
        xCurGradient = problem.gradAlt(xCur, options.discrepency);
    else
        xCurGradient = getGradient(problem, xCur);
    end
    xCurGradNorm = M.norm(xCur, xCurGradient);
    xCurCost = getCost(problem, xCur);
    
    k = 0;
    iter = 0;
    sHistory = cell(1, options.memory);
    yHistory = cell(1, options.memory);
    rhoHistory = cell(1, options.memory);
    alpha = 1;
    scaleFactor = 1;
    stepsize = 1;
    existsAssumedoptX = exist('options','var') && ~isempty(options) && exist('options.assumedoptX', 'var');
    lsiters = 1;
    ultimatum = 0;
    pushforward = 0;
    
    
    stats.gradnorms = zeros(1,options.maxiter);
    stats.alphas = zeros(1,options.maxiter);
    stats.stepsizes = zeros(1,options.maxiter);
    stats.costs = zeros(1,options.maxiter);
    stats.xHistory = cell(1,options.maxiter);
    if existsAssumedoptX
        stats.distToAssumedOptX = zeros(1,options.maxiter);
    end
    
    savestats();

    fprintf(' iter\t               cost val\t    grad. norm\t   lsiters\n');

    
    while (1)
        
        if pushforward == 1
            if options.discrepency > options.maxdiscrepency && options.useProgressiveTol == 1
                options.discrepency = options.discrepency*options.discrepencydownscalefactor;
                if options.discrepency < options.maxdiscrepency
                    options.tolgradnorm = options.finalgradnorm;
                end
                fprintf('current discrepency is %.16e \n', options.discrepency);
                pushforward = 0;
                k = 0;
                sHistory = cell(1, options.memory);
                yHistory = cell(1, options.memory);
                rhoHistory = cell(1, options.memory);
                alpha = 1;
                scaleFactor = stepsize * 2/xCurGradNorm; %Need to reconsider
                if (options.useProgressiveTol == 1)
                    xCurGradient = problem.gradAlt(xCur, options.discrepency);
                else
                    xCurGradient = getGradient(problem, xCur);
                end
                xCurGradNorm = M.norm(xCur, xCurGradient);
                xCurCost = getCost(problem, xCur);
                stepsize = 1;
                continue;
            else
                break;
            end
        end
        if ultimatum == 0
            %_______Print Information and stop information________
            fprintf('%5d\t%+.16e\t%.8e\t %d\n', iter, xCurCost, xCurGradNorm, lsiters);
        end
        
        if (xCurGradNorm < options.tolgradnorm)
            fprintf('Target Reached\n');
            pushforward = 1;
            continue;
        end
        if (stepsize <= options.minstepsize)
            fprintf('Stepsize too small\n')
            pushforward = 1;
            continue;
        end
        if (iter > options.maxiter)
            fprintf('maxiter reached\n')
            pushforward = 1;
            continue;
        end

        %_______Get Direction___________________________

       p = getDirection(M, xCur, xCurGradient, sHistory,...
            yHistory, rhoHistory, scaleFactor, min(k, options.memory));
        
%         p = -getGradient(problem, xCur);
        
        %_______Line Search____________________________
        dir_derivative = M.inner(xCur,xCurGradient,p);
        if  dir_derivative> 0
            fprintf('directionderivative IS POSITIVE\n');
        end

        [xNextCost, alpha, fail, lsiters] = linesearchnonsmooth(problem, M, xCur, p, xCurCost, dir_derivative, options.c1, options.c2, options.lsmaxcounter);
        step = M.lincomb(xCur, alpha, p);
        newstepsize = M.norm(xCur, step);
        if fail == 1 || newstepsize < 1e-14
            if ultimatum == 1
                fprintf('Even descent direction does not help us now\n');
                pushforward = 1;
                continue;
            else
                k = 0;
                scaleFactor = stepsize*2/xCurGradNorm;
                ultimatum = 1;
                continue;
            end
        else
            ultimatum = 0;
        end
        stepsize = newstepsize;
        xNext = M.retr(xCur, step, 1);
        
        %_______Updating the next iteration_______________
        if (options.useProgressiveTol == 1)
            xNextGradient = problem.gradAlt(xNext, options.discrepency);
        else
            xNextGradient = getGradient(problem, xNext);
        end
        
        sk = M.transp(xCur, xNext, step);
        yk = M.lincomb(xNext, 1, xNextGradient,...
            -1, M.transp(xCur, xNext, xCurGradient));
        
        inner_sk_yk = M.inner(xNext, yk, sk);
        arbconst = 0;
        if (inner_sk_yk /M.inner(xNext, sk, sk))> arbconst * xCurGradNorm
            rhok = 1/inner_sk_yk;
            scaleFactor = inner_sk_yk / M.inner(xNext, yk, yk);
            if (k>= options.memory)
                for  i = 2:options.memory
                    sHistory{i} = M.transp(xCur, xNext, sHistory{i});
                    yHistory{i} = M.transp(xCur, xNext, yHistory{i});
                end
                sHistory = sHistory([2:end 1]);
                sHistory{options.memory} = sk;
                yHistory = yHistory([2:end 1]);
                yHistory{options.memory} = yk;
                rhoHistory = rhoHistory([2:end 1]);
                rhoHistory{options.memory} = rhok;
            else
                for  i = 1:k
                    sHistory{i} = M.transp(xCur, xNext, sHistory{i});
                    yHistory{i} = M.transp(xCur, xNext, yHistory{i});
                end
                sHistory{k+1} = sk;
                yHistory{k+1} = yk;
                rhoHistory{k+1} = rhok;
            end
            k = k+1;
        else
            for  i = 1:min(k,options.memory)
                sHistory{i} = M.transp(xCur, xNext, sHistory{i});
                yHistory{i} = M.transp(xCur, xNext, yHistory{i});
            end
        end

        iter = iter + 1;
        xCur = xNext;
        xCurGradient = xNextGradient;
        xCurGradNorm = M.norm(xCur, xNextGradient);
        xCurCost = xNextCost;
      
        
        savestats()
    end
    
    stats.gradnorms = stats.gradnorms(1,1:iter+1);
    stats.alphas = stats.alphas(1,1:iter+1);
    stats.costs = stats.costs(1,1:iter+1);
    stats.stepsizes = stats.stepsizes(1,1:iter+1);
    stats.xHistory= stats.xHistory(1,1:iter+1);
    stats.time = toc(timetic);
    if existsAssumedoptX
        stats.distToAssumedOptX = stats.distToAssumedOptX(1, 1:iter+1);
    end
    finalX = xCur;
    
    function savestats()
        stats.gradnorms(1, iter+1)= xCurGradNorm;
        stats.alphas(1, iter+1) = alpha;
        stats.stepsizes(1, iter+1) = stepsize;
        stats.costs(1, iter+1) = xCurCost;
        if existsAssumedoptX
            stats.distToAssumedOptX(1, iter+1) = M.dist(xCur, options.assumedoptX);
        end
        stats.xHistory{iter+1} = xCur;
    end

end

function dir = getDirection(M, xCur, xCurGradient, sHistory, yHistory, rhoHistory, scaleFactor, k)
    q = xCurGradient;
    inner_s_q = cell(1, k);
    for i = k : -1: 1
        inner_s_q{i} = rhoHistory{i}*M.inner(xCur, sHistory{i},q);
        q = M.lincomb(xCur, 1, q, -inner_s_q{i}, yHistory{i});
    end
    r = M.lincomb(xCur, scaleFactor, q);
    for i = 1: k
         omega = rhoHistory{i}*M.inner(xCur, yHistory{i}, r);
         r = M.lincomb(xCur, 1, r, inner_s_q{i}-omega, sHistory{i});
    end
    dir = M.lincomb(xCur, -1, r);
end


function [costNext, t, fail, lsiters] = linesearchnonsmooth(problem, M, xCur, d, f0, df0, c1, c2, max_counter)
%     df0 = M.inner(xCur, problem.reallygrad(xCur), d);
    if M.inner(xCur, problem.reallygrad(xCur), d) >=0
        fprintf('LS failure by wrong direction');
        t = 1;
        fail = 1;
        costNext = inf;
        lsiters = -1;
        return
    end
    alpha = 0;
    fail = 0;
    beta = inf;
    t = 1;
    counter = max_counter;
    while counter > 0
        xNext = M.retr(xCur, d, t);
        if (getCost(problem, xNext) > f0 + df0*c1*t)
            beta = t;
        elseif diffretractionGrassman(problem, M, t, d, xCur, xNext) < c2*df0
            alpha = t;
        else
            break;
        end
        if (isinf(beta))
            t = alpha*2;
        else
            t = (alpha+beta)/2;
        end
        counter = counter - 1;
    end
    if counter == 0
        fprintf('Failed LS \n');
        fail = 1;
    end
    costNext = getCost(problem, xNext);
    lsiters = max_counter - counter + 1;
end


function slope = diffretractionGrassman(problem, M, alpha, p, xCur, xNext)

    X = xCur + alpha*p;
    [Q, R] = qr(X, 0); %ok
    Q = Q * diag(sign(diag(R)));
    invR = inv(R); %Terrible
    temp1 = p*invR;
    temp2 = Q.'*temp1;
    L = tril(temp2, -1);
    Lt = L-L.';
    dir = X*Lt+(temp1 - X*(X.'*temp1));
    slope = M.inner(xNext, getGradient(problem, xNext), dir);
    
%    
%     retrstep = 1e-10;
%     slope = (getCost(problem, M.retr(xNext, p, retrstep)) - getCost(problem, xNext))/retrstep;
%     
%     slope - slope_num
end

