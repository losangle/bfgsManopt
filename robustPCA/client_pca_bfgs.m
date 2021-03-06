function client_pca_bfgs
%     rng(161616);
    Dim = 2;
    dim = 1;
    N_in = 500;
    N_out = 500;
    discrepencyAcc = 1e-13;
    Lambda_in = eye(dim);
%     for c = 1 : dim
%         Lambda_in(c,c) = c;
%     end
    %TO DO randomly generate V
    V = zeros(Dim, dim);
    V(1:dim,1:dim) = eye(dim);
    Sig_in = V*Lambda_in*V.';
%     Sig_out = randn(Dim);
%     Sig_out = Sig_out.'*Sig_out;
    Sig_out = eye(Dim);
    X= zeros(N_in+N_out, Dim);
    mu = zeros(Dim, 1);
    X(1: N_in, :) = mvnrnd(mu, Sig_in, N_in);
    X(N_in+1: N_in+N_out, :) = mvnrnd(mu, Sig_out/rank(Sig_out), N_out);
%     for c = N_in +1: N_in + N_out
%         X(:, c) =
%     end
    X = X.';
    
    manifold = grassmannfactory(Dim, dim);
    problem.M = manifold;

    cost = @(V) costFun(V, X);
    subgrad = @(V) subgradFun(V, X, discrepencyAcc);
    subgradTol = @(V, disc) subgradTolFun(V, X, disc);
    
    problem.cost  = cost;
    problem.grad = subgrad;
    problem.reallygrad = subgrad;
    problem.gradAlt = subgradTol;
    
%     checkgradient(problem);

    options = [];
    options.assumedoptX = problem.M.rand();
    [U_start, S_start, V_start] = svd(X);
    VCur = U_start(:, 1: dim);
    
%     [v, cost, info, options] = steepestdescent(problem, VCur, options);
%     figure
%     h = logspace(-15, 1, 501);
%     vals = zeros(1, 501);
%     for iter = 1:501
%         vals(1,iter) = problem.M.norm(v, subgradFun(v, X, h(iter)));
%     end
%     loglog(h, vals)
    
    profile clear
    profile on
    [stats, v] = bfgsnonsmooth_pca(problem, VCur, options);
    profile off
    profile report
    
    figure
    h = logspace(-15, 1, 501);
    vals = zeros(1, 501);
    for iter = 1:501
        vals(1,iter) = problem.M.norm(v, subgradFun(v, X, h(iter)));
    end
    loglog(h, vals)
    
    
    
    format long e
%     v
    figure
    scatter(X(1, :), X(2, :));
    hold on
    plot([0;v(1)],[0;v(2)], 'LineWidth', 5);
    axis([-3 3 -3 3])
    hold off
    figure 
    surfprofile(problem, v);
%     figure
%     plotprofile(problem, v, problem.M.randvec(v), linspace(-10,10,501));
    displaystats(stats);
    
    
    
    
    function val = costFun(V, X)
        projectedX = X - V*(V.'*X);
        [row, col] = size(projectedX);
        val = 0;
        for c = 1: col
            val = val + norm(projectedX(:, c), 2);
        end
    end

    function grad = subgradFun(V, X, discrepency)
        grad = zeros(size(V));
        projectedX = X - V*(V.'*X);
        [row, col] = size(projectedX);
        for c = 1: col
            norm_xi = norm(projectedX(:, c), 2);
            if norm_xi > discrepency
                grad = grad + (1/norm_xi) * X(:, c)* (X(:, c).' * V);
            end
        end
        grad = - grad;
        grad = grad - V*(V.'*grad);
    end

    function grad = subgradTolFun(V, X, disc)
        grad = zeros(size(V));
        projectedX = X - V*(V.'*X);
        [row, col] = size(projectedX);
        for c = 1: col
            norm_xi = norm(projectedX(:, c), 2);
            if norm_xi > disc
                grad = grad + (1/norm_xi) * X(:, c)* (X(:, c).' * V);
            end
        end
        grad = - grad;
        grad = grad - V*(V.'*grad);
    end
    
    
    function displaystats(stats)
        
        finalcost = stats.costs(end);
        for numcost = 1 : length(stats.costs)
            stats.costs(1,numcost) = stats.costs(1,numcost) - finalcost;
        end
        figure;
        
        subplot(2,2,1)
        semilogy(stats.gradnorms, '.-');
        xlabel('Iter');
        ylabel('GradNorms');
        
        titletest = sprintf('Time: %f', stats.time);
        title(titletest);
        
        subplot(2,2,2)
        plot(stats.alphas, '.-');
        xlabel('Iter');
        ylabel('Alphas');
        
        subplot(2,2,3)
        semilogy(stats.stepsizes, '.-');
        xlabel('Iter');
        ylabel('stepsizes');
        
        subplot(2,2,4)
        semilogy(stats.costs, '.-');
        xlabel('Iter');
        ylabel('costs');
    end

end