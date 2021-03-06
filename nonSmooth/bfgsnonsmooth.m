function [gradnorms, alphas, stepsizes, costs, distToAssumedOptX, xHistory, xCur, time] = bfgsnonsmooth(problem, x, options)
    
    timetic = tic();
    M = problem.M;

    if ~exist('x','var')
        xCur = x;
    else
        xCur = M.rand();
    end

    xCur = x;
    
    localdefaults.minstepsize = 1e-50;
    localdefaults.maxiter = 20000;
    localdefaults.tolgradnorm = 1e-12;
    localdefaults.memory = 20;
    localdefaults.linesearchVersion = 4;
    localdefaults.c1 = 0.0; %need adjust
    localdefaults.c2 = 0.5; %need adjust.
    localdefaults.discrepency = 1e-4;
    
    % Merge global and local defaults, then merge w/ user options, if any.
    localdefaults = mergeOptions(getGlobalDefaults(), localdefaults);
    if ~exist('options', 'var') || isempty(options)
        options = struct();
    end
    options = mergeOptions(localdefaults, options);
   

    xCurGradient = getGradient(problem, xCur);
%     xCurGradient = problem.gradAlt(xCur, options.discrepency);
    xCurGradNorm = M.norm(xCur, xCurGradient);
    xCurCost = getCost(problem, xCur);
    
    
    gradnorms = zeros(1,options.maxiter);
    gradnorms(1,1) = xCurGradNorm;
    alphas = zeros(1,options.maxiter);
    alphas(1,1) = 1;
    stepsizes = zeros(1,options.maxiter);
    stepsizes(1,1) = NaN;
    costs = zeros(1,options.maxiter);
    costs(1,1) = xCurCost;
    distToAssumedOptX = zeros(1,options.maxiter);
    distToAssumedOptX(1,1) = M.dist(xCur, options.assumedoptX);
    xHistory = cell(1,options.maxiter);
    xHistory{1} = xCur;


    k = 0;
    iter = 0;
    sHistory = cell(1, options.memory);
    yHistory = cell(1, options.memory);
    rhoHistory = cell(1, options.memory);
    alpha = 1;
    scaleFactor = 1;
    stepsize = 1;
    lsiters = 1;
    ultimatum = 0;
    gradonballs_limit = 7;
    gradonballs = 0;

    fprintf(' iter\t               cost val\t    grad. norm\t   lsiters\n');

    while (1)
        %_______Print Information and stop information________
        fprintf('%5d\t%+.16e\t%.8e\t %d\n', iter, xCurCost, xCurGradNorm, lsiters);

        if (xCurGradNorm < options.tolgradnorm)
            fprintf('Target Reached\n');
            break;
        end
        if (stepsize <= options.minstepsize)
            fprintf('Stepsize too small\n')
            break;
        end
        if (iter > options.maxiter)
            fprintf('maxiter reached\n')
            break;
        end

        %_______Get Direction___________________________

        p = getDirection(M, xCur, xCurGradient, sHistory,...
            yHistory, rhoHistory, scaleFactor, min(k, options.memory));
        if isnan(p(1,1))
            getDirection(M, xCur, xCurGradient, sHistory,...
            yHistory, rhoHistory, scaleFactor, min(k, options.memory));
        end
        
        %_______Line Search____________________________

        if options.linesearchVersion == 0
            alpha = 0.5;
            [alpha, xNext, xNextCost] = linesearchBFGS(problem,...
                xCur, p, xCurCost, M.inner(xCur,xCurGradient,p), alpha); %Check if df0 is right
            step = M.lincomb(xCur, alpha, p);
            stepsize = M.norm(xCur, p)*alpha;
        elseif options.linesearchVersion == 1
            [stepsize, xNext, newkey, lsstats] =linesearch(problem, xCur, p, xCurCost, M.inner(xCur,xCurGradient,p));
            alpha = stepsize/M.norm(xCur, p);
            step = M.lincomb(xCur, alpha, p);
            xNextCost = getCost(problem, xNext);
        elseif options.linesearchVersion == 2
            [xNextCost,alpha] = linesearchv2(problem, M, xCur, p, M.inner(xCur,xCurGradient,p), alpha);
            step = M.lincomb(xCur, alpha, p);
            stepsize = M.norm(xCur, step);
            xNext = M.retr(xCur, step, 1);
        elseif options.linesearchVersion == 3
            alpha = 1;
            step = M.lincomb(xCur, alpha, p);
            stepsize = M.norm(xCur, step);
            xNext = M.retr(xCur, step, 1);
            xNextCost = getCost(problem, xNext);
        else
            [xNextCost, alpha, fail, lsiters] = linesearchnonsmooth(problem, M, xCur, p, xCurCost, M.inner(xCur,xCurGradient,p), options.c1, options.c2, alpha);
            step = M.lincomb(xCur, alpha, p);
            stepsize = M.norm(xCur, step);
            xNext = M.retr(xCur, step, 1);
            if fail == 1 || stepsize < 1e-14
                if ultimatum == 1
                    fprintf('Even descent direction does not help us now\n');
                    break;
                else
                    k = 0;
                    scaleFactor = 1;
                    ultimatum = 1;
                    continue;
                end
            else
                ultimatum = 0;
            end
        end
        
        %_______Updating the next iteration_______________
        xNextGradient = getGradient(problem, xNext);
%         xNextGradient = problem.gradAlt(xNext, options.discrepency);        
%         if M.norm(xNext, problem.gradAlt(xNext, options.discrepency*10)) < 1e-6
%             fprintf('Descrease Discrepency \n');
%             options.discrepency = options.discrepency/10;
%             k=0;
%             scaleFactor = 1;
%             continue;
%         end
        
        
        
        sk = M.isotransp(xCur, xNext, step);
        yk = M.lincomb(xNext, 1, xNextGradient,...
            -1, M.isotransp(xCur, xNext, xCurGradient));

        inner_sk_yk = M.inner(xNext, yk, sk);
        arbconst = 0;
        if (inner_sk_yk /M.inner(xNext, sk, sk))> arbconst * xCurGradNorm
            rhok = 1/inner_sk_yk;
            scaleFactor = inner_sk_yk / M.inner(xNext, yk, yk);
            if (k>= options.memory)
                for  i = 2:options.memory
                    sHistory{i} = M.isotransp(xCur, xNext, sHistory{i});
                    yHistory{i} = M.isotransp(xCur, xNext, yHistory{i});
                end
                sHistory = sHistory([2:end 1]);
                sHistory{options.memory} = sk;
                yHistory = yHistory([2:end 1]);
                yHistory{options.memory} = yk;
                rhoHistory = rhoHistory([2:end 1]);
                rhoHistory{options.memory} = rhok;
            else
                for  i = 1:k
                    sHistory{i} = M.isotransp(xCur, xNext, sHistory{i});
                    yHistory{i} = M.isotransp(xCur, xNext, yHistory{i});
                end
                sHistory{k+1} = sk;
                yHistory{k+1} = yk;
                rhoHistory{k+1} = rhok;
            end
            k = k+1;
        else
            for  i = 1:min(k,options.memory)
                sHistory{i} = M.isotransp(xCur, xNext, sHistory{i});
                yHistory{i} = M.isotransp(xCur, xNext, yHistory{i});
            end
        end

        iter = iter + 1;
        xCur = xNext;
        xCurGradient = xNextGradient;
        xCurGradNorm = M.norm(xCur, xNextGradient);
        xCurCost = xNextCost;
        
        gradnorms(1, iter+1)= xCurGradNorm;
        alphas(1, iter+1) = alpha;
        stepsizes(1, iter+1) = stepsize;
        costs(1, iter+1) = xCurCost;
        distToAssumedOptX(1, iter+1) = M.dist(xCur, options.assumedoptX);
        xHistory{iter+1} = xCur;
    end
    
    gradnorms = gradnorms(1,1:iter+1);
    alphas = alphas(1,1:iter+1);
    costs = costs(1,1:iter+1);
    stepsizes = stepsizes(1,1:iter+1);
    distToAssumedOptX = distToAssumedOptX(1, 1:iter+1);
    xHistory= xHistory(1,1:iter+1);
    time = toc(timetic);
end

function dir = getDirection(M, xCur, xCurGradient, sHistory, yHistory, rhoHistory, scaleFactor, k)
    q = xCurGradient;
    inner_s_q = cell(1, k);
    for i = k : -1: 1
        inner_s_q{i} = rhoHistory{i}*M.inner(xCur, sHistory{i},q);
        q = M.lincomb(xCur, 1, q, -inner_s_q{i}, yHistory{i});
    end
    %DEBUGonly
    fprintf('norm of q = %.16e', M.norm(xCur,q));
    if M.norm(xCur, q)> 1e+20
        whatisthis = 1;
    end
    
    r = M.lincomb(xCur, scaleFactor, q);
    for i = 1: k
         omega = rhoHistory{i}*M.inner(xCur, yHistory{i}, r);
         r = M.lincomb(xCur, 1, r, inner_s_q{i}-omega, sHistory{i});
    end
    dir = M.lincomb(xCur, -1, r);
end


function [alpha, xNext, xNextCost] = ...
                  linesearchBFGS(problem, x, d, f0, df0, alphaprev)

    % Backtracking default parameters. These can be overwritten in the
    % options structure which is passed to the solver.
    contraction_factor = .5;
    optimism = 1/.5;
    suff_decr = 1e-4;
%     suff_decr = 0;
    max_steps = 25;
    
    % At first, we have no idea of what the step size should be.
    alpha = alphaprev * optimism;

    % Make the chosen step and compute the cost there.
    xNext = problem.M.retr(x, d, alpha);
    xNextCost = getCost(problem, xNext);
    cost_evaluations = 1;
    
    % Backtrack while the Armijo criterion is not satisfied
    while xNextCost > f0 + suff_decr*alpha*df0
        
        % Reduce the step size,
        alpha = contraction_factor * alpha;
        
        % and look closer down the line
        xNext = problem.M.retr(x, d, alpha);
        xNextCost = getCost(problem, xNext);
        cost_evaluations = cost_evaluations + 1;
        
        % Make sure we don't run out of budget
        if cost_evaluations >= max_steps
            break;
        end
        
    end
    
    % If we got here without obtaining a decrease, we reject the step.
    if xNextCost > f0
        alpha = 0;
        xNext = x;
        xNextCost = f0; 
    end
    
%     fprintf('alpha = %.16e\n', alpha)
end


function [costNext,alpha] = linesearchv2(problem, M, x, d, df0, alphaprev)

    alpha = alphaprev;
    costAtx = getCost(problem,x);
    while (getCost(problem,M.retr(x,d,2*alpha))-costAtx < alpha*df0)
        alpha = 2*alpha;
    end
    costNext = getCost(problem,M.retr(x,d,alpha));
    diff = costNext - costAtx;
    while (diff>= 0.5*alpha*df0)
        if (diff == 0)
            alpha = 0;
            break;
        end
        alpha = 0.5 * alpha;
        costNext = getCost(problem,M.retr(x,d,alpha));
        diff = costNext - costAtx;
    end
%     fprintf('alpha = %.16e\n',alpha);    
end

function [costNext, t, fail, lsiters] = linesearchnonsmooth(problem, M, xCur, d, f0, df0, c1, c2, alphaprev)
    if  problem.M.inner(xCur, problem.grad(xCur), d) > 0
        fprintf('directionderivative IS POSITIVE\n');
    end
    alpha = 0;
    fail = 0;
    beta = inf;
    t = 1;
    max_counter = 100;
    counter = max_counter;
    while counter > 0
        xNext = M.retr(xCur, d, t);
        if (getCost(problem, xNext) > f0 + df0*c1*t)
            beta = t;
        elseif diffretractionOblique(problem, M, t, d, xCur, xNext) < c2*df0
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


function slope = diffretractionOblique(problem, M, alpha, p, xCur, xNext)
    [n, m] = size(p);
    diffretr = zeros(n, m);
    for i = 1 : m
        d = p(:, i);
        dInner = d.' * d;
        diffretr(:,i) = (d-alpha*dInner*xCur(:, i)) /sqrt((1+dInner * alpha^2)^3);
    end
    %Can be optimized.
    slope = M.inner(xNext, problem.reallygrad(xNext), diffretr);
%     slope = M.inner(xNext, getGradient(problem, xNext), diffretr);
end
