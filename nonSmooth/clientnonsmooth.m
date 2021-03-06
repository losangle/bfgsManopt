function clientnonsmooth

    d = 3;
    n = 8;
    % Create the problem structure.
    manifold = obliquefactory(d,n);
    problem.M = manifold;
    
    discrepency = 1e-4;
    
    cost = @(X) costFun(X);
    grad = @(X) newgradFun(manifold, X, discrepency);
    gradFunc = @(X) gradFun(X);
    failedgradFunc = @(X) failedgradFun(X);
    gradAlt = @(X, discre) newgradFun(manifold, X, discre);
    
    % Define the problem cost function and its Euclidean gradient.
    problem.cost  = cost;
    problem.grad = grad;
    problem.gradAlt = gradAlt;
    problem.reallygrad = gradFunc;
    
%     checkgradient(problem);
    
    %Set options
    options.linesearchVersion = 4;
    options.memory = 20;

    xCur = problem.M.rand();
    options.assumedoptX = problem.M.rand();
    
    profile clear;
    profile on;

    [gradnorms, alphas, stepsizes, costs, distToAssumedOptX, xHistory, X, time]  = bfgsnonsmooth(problem, xCur, options);
    
    figure
    h = logspace(-15, 1, 501);
    vals = zeros(1, 501);
    for iter = 1:501
    vals(1,iter) = problem.M.norm(X, newgradFun(problem.M, X, h(iter)));
    end
    loglog(h, vals)
    
    discrepency = discrepency/10;
    grad = @(X) newgradFun(manifold, X, discrepency);
    problem.grad = grad;
    [gradnorms, alphas, stepsizes, costs, distToAssumedOptX, xHistory, X, time]  = bfgsnonsmooth(problem, X, options);
    figure
    h = logspace(-15, 1, 501);
    vals = zeros(1, 501);
    for iter = 1:501
    vals(1,iter) = problem.M.norm(X, newgradFun(problem.M, X, h(iter)));
    end
    loglog(h, vals)
    
    discrepency = discrepency/10;
    grad = @(X) newgradFun(manifold, X, discrepency);
    problem.grad = grad;
    [gradnorms, alphas, stepsizes, costs, distToAssumedOptX, xHistory, X, time]  = bfgsnonsmooth(problem, X, options);
    figure
    h = logspace(-15, 1, 501);
    vals = zeros(1, 501);
    for iter = 1:501
    vals(1,iter) = problem.M.norm(X, newgradFun(problem.M, X, h(iter)));
    end
    loglog(h, vals)
    
    discrepency = discrepency/10;
    grad = @(X) newgradFun(manifold, X, discrepency);
    problem.grad = grad;
    [gradnorms, alphas, stepsizes, costs, distToAssumedOptX, xHistory, X, time]  = bfgsnonsmooth(problem, X, options);
    figure
    h = logspace(-15, 1, 501);
    vals = zeros(1, 501);
    for iter = 1:501
    vals(1,iter) = problem.M.norm(X, newgradFun(problem.M, X, h(iter)));
    end
    loglog(h, vals)
    

    profile off;
    profile report
   
   
    figure;
    
    subplot(2,2,1)
    semilogy(gradnorms, '.-');
    xlabel('Iter');
    ylabel('GradNorms');

    titletest = sprintf('Time: %f', time);
    title(titletest);
    
    subplot(2,2,2)
    plot(alphas, '.-');
    xlabel('Iter');
    ylabel('Alphas');

    subplot(2,2,3)
    semilogy(stepsizes, '.-');
    xlabel('Iter');
    ylabel('stepsizes');

    subplot(2,2,4)
    semilogy(costs, '.-');
    xlabel('Iter');
    ylabel('costs');
    

    
    
    maxdot = costFun(X);
    
    % Similarly, even though we did not specify the Hessian, we may still
    % estimate its spectrum at the solution. It should reflect the
    % invariance of the cost function under a global rotatioon of the
    % sphere, which is an invariance under the group O(d) of dimension
    % d(d-1)/2 : this translates into d(d-1)/2 zero eigenvalues in the
    % spectrum of the Hessian.
    % The approximate Hessian is not a linear operator, and is it a
    % fortiori not symmetric. The result of this computation is thus not
    % reliable. It does display the zero eigenvalues as expected though.
    if manifold.dim() < 300
        evs = real(hessianspectrum(problem, X));
        figure;
        stem(1:length(evs), sort(evs), '.');
        title(['Eigenvalues of the approximate Hessian of the cost ' ...
               'function at the solution']);
    end
    
    
    % Give some visualization if the dimension allows
    if d == 2
        % For the circle, the optimal solution consists in spreading the
        % points with angles uniformly sampled in (0, 2pi). This
        % corresponds to the following value for the max inner product:
        fprintf('Optimal value for the max inner product: %g\n', cos(2*pi/n));
        figure;
        t = linspace(-pi, pi, 201);
        plot(cos(t), sin(t), '-', 'LineWidth', 3, 'Color', [152,186,220]/255);
        daspect([1 1 1]);
        box off;
        axis off;
        hold on;
        plot(X(:, 1), X(:, 2), 'r.', 'MarkerSize', 25);
        hold off;
    end
    if d == 3
        figure;
        % Plot the sphere
        [sphere_x, sphere_y, sphere_z] = sphere(50);
        handle = surf(sphere_x, sphere_y, sphere_z);
        set(handle, 'FaceColor', [152,186,220]/255);
        set(handle, 'FaceAlpha', .5);
        set(handle, 'EdgeColor', [152,186,220]/255);
        set(handle, 'EdgeAlpha', .5);
        daspect([1 1 1]);
        box off;
        axis off;
        hold on;
        % Add the chosen points
        Y = 1.02*X;
        plot3(Y(1, :), Y(2, :), Y(3, :), 'r.', 'MarkerSize', 25);
        % And connect the points which are at minimal distance,
        % within some tolerance.
        min_distance = real(acos(maxdot));
        connected = real(acos(X.'*X)) <= 1.20*min_distance;
        [Ic, Jc] = find(triu(connected, 1));
        for k = 1 : length(Ic)
            i = Ic(k); j = Jc(k);
            plot3(Y(1, [i j]), Y(2, [i j]), Y(3, [i j]), 'k-');
        end
        hold off;
    end
    
    
%     bfgsIsometric(problem, xCur, options);
%    bfgsClean(problem, xCur, options);
%     %trustregions(problem, xCur, options);
%     options.maxiter = 20000;
%     steepestdescent(problem, xCur, options);
    
%     profile clear;
%     profile on;
% 
%     bfgsClean(problem,xCur,options);
% 
% 
%     profile off;
%     profile report

    % This can change, but should be indifferent for various
    % solvers.
    % Integrating costGrad and cost probably halves the time
        function val = costFun(X)
            Inner = X.'*X;
            Inner(1:size(Inner,1)+1:end) = -2;
            val = max(Inner(:));
%             Inner(eye(size(Inner,1))==1) = -2;
        end

    function u = newgradFun(M, X, discrepency)
        if (~exist('discrepency', 'var'))
            discrepency = 1e-5;
        end
        counter = 0;
        pairs = [];
        Inner = X.'*X;
        m = size(Inner, 1);
        Inner(1: m+1: end) = -2;
        %             Inner(eye(m)==1) = -2;
        [maxval,pos] = max(Inner(:));
        for row = 1: m
            for col = row+1:m
                if abs(Inner(row, col)-maxval) <= discrepency
                    counter = counter +1;
                    pairs{counter} = [row, col];
                end
            end
        end
%         if counter > 3
%             what = 1;
%         end
        grads = cell(1, counter);
        for iterator = 1 : counter
            val = zeros(size(X));
            pair = pairs{iterator};
            Innerprod = X(:, pair(1)).'*X(:, pair(2));
            val(:, pair(1)) = X(:, pair(2)) - Innerprod*X(:,pair(1));
            val(:, pair(2)) = X(:, pair(1)) - Innerprod*X(:,pair(2));
            grads{iterator} = val;
        end
        [u_norm, coeffs, u] = smallestinconvexhull(M, X, grads);
        %             fprintf('counter = %d\n', counter);
    end
    
        function val = failedgradFun(X)
            discrepency = 1e-4;
            counter = 0;
            pairs = [];
            Inner = X.'*X;
            m = size(Inner, 1);
            Inner(1: m+1: end) = -2;
%             Inner(eye(m)==1) = -2;
            [maxval,pos] = max(Inner(:));
            for row = 1: m
                for col = row+1:m
                    if abs(Inner(row, col)-maxval) <= discrepency
                        counter = counter +1;
                        pairs{counter} = [row, col];
                    end
                end
            end
            val = zeros(size(X));
            for t = 1 : counter
                pair = pairs{t};
                val(:, pair(1)) = val(:, pair(1)) + X(:, pair(2));
                val(:, pair(2)) = val(:, pair(2)) + X(:, pair(1));
            end
            val = val/counter;
%             fprintf('counter = %d\n', counter);
        end
    
        function val = gradFun(X)
            Inner = X.'*X;
            m = size(Inner,1);
            Inner(1:m+1:end) = -2;
%             Inner(eye(m)==1) = -2;
            [maxval,pos] = max(Inner(:));
            i = mod(pos-1,m)+1;
            j = floor((pos-1)/m)+1;
            val = zeros(size(X));
            val(:,i) = X(:,j);
            val(:,j) = X(:,i);
        end
end

