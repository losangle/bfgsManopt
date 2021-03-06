function [gradnorms, alphas, time] = bfgsClean(problem, x, options)
    
    timetic = tic();
    M = problem.M;

    if ~exist('x','var')|| isempty(x)
        xCur = x;
    else
        xCur = M.rand();
    end

    xCurGradient = getGradient(problem, xCur);
    xCurGradNorm = M.norm(xCur, xCurGradient);
    xCurCost = getCost(problem, xCur);
    
    
    gradnorms = zeros(1,1000);
    gradnorms(1,1) = xCurGradNorm;
    alphas = zeros(1,1000);
    alphas(1,1) = 1;
    

    options.error = 1e-7;
    options.memory = 20;


    k = 0;
    iter = 0;
    sHistory = cell(1, options.memory);
    yHistory = cell(1, options.memory);
    rhoHistory = cell(1, options.memory);
    alpha = 1;
    scaleFactor = 1;
    stepsize = 1;

    fprintf(' iter\t               cost val\t    grad. norm\t   alpha \n');

    while (1)
        %_______Print Information and stop information________
        fprintf('%5d\t%+.16e\t%.8e\n', iter, xCurCost, xCurGradNorm);

        if (xCurGradNorm < options.error)
            fprintf('Target Reached\b');
            break;
        end
        if (stepsize <= 1e-10)
            fprintf('Stepsize too small\n')
            break;
        end

        %_______Get Direction___________________________

        p = getDirection(M, xCur, xCurGradient, sHistory,...
            yHistory, rhoHistory, scaleFactor, min(k, options.memory));

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
            xNext = M.exp(xCur, step, 1);
        else
            alpha = 1;
            step = M.lincomb(xCur, alpha, p);
            stepsize = M.norm(xCur, step);
            xNext = M.retr(xCur, step, 1);
            xNextCost = getCost(problem, xNext);
        end
        
        %_______Updating the next iteration_______________
        xNextGradient = getGradient(problem, xNext);
        sk = M.transp(xCur, xNext, step);
        yk = M.lincomb(xNext, 1, xNextGradient,...
            -1, M.transp(xCur, xNext, xCurGradient));

        inner_sk_yk = M.inner(xNext, yk, sk);
        if (inner_sk_yk /M.inner(xNext, sk, sk))>= xCurGradNorm
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
        
        gradnorms(1,iter+1)= xCurGradNorm;
        alphas(1,iter+1) = alpha;
    end
    
    gradnorms = gradnorms(1,1:iter+1);
    alphas = alphas(1,1:iter+1);
    time = toc(timetic);
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
         omega = rhoHistory{i}*M.inner(xCur, yHistory{i},r);
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


function [costNext,alpha] = linesearchv2(problem, M, x, p, pTGradAtx, alphaprev)

    alpha = alphaprev;
    costAtx = getCost(problem,x);
    while (getCost(problem,M.exp(x,p,2*alpha))-costAtx < alpha*pTGradAtx)
        alpha = 2*alpha;
    end
    costNext = getCost(problem,M.exp(x,p,alpha));
    diff = costNext - costAtx;
    while (diff>= 0.5*alpha*pTGradAtx)
        if (diff == 0)
            alpha = 0;
            break;
        end
        alpha = 0.5 * alpha;
        costNext = getCost(problem,M.exp(x,p,alpha));
        diff = costNext - costAtx;
    end
%     fprintf('alpha = %.16e\n',alpha);    
end
