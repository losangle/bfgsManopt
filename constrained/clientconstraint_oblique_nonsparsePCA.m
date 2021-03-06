function clientconstraint_oblique_nonsparsePCA
close all; clc; clear all;
rng(11);
Dim = 8;
rank = 1;

A = randn(Dim);


manifold = obliquefactory(Dim, rank);
problem.M = manifold;
problem.cost = @(u) costfun(u);
problem.egrad = @(u) gradfun(u);

checkgradient(problem);

constraints_cost = cell(1, Dim*rank);
for row = 1: Dim
    for col = 1: rank
        constraints_cost{(col-1)*Dim + row} = @(U) U(row, col);
    end
end

constraints_grad = cell(1, Dim * rank);
for row = 1: Dim
    for col = 1: rank
        constraintgrad = zeros(Dim, rank);
        constraintgrad(row, col) = 1;
        constraints_grad{(col-1)*Dim + row} = @(U) constraintgrad;
    end
end

problem.ineq_constraint_cost = constraints_cost;
problem.ineq_constraint_grad = constraints_grad;


% for i = 1:Dim * rank
%     newproblem.M = manifold;
%     newproblem.cost = constraints_cost{i};
%     newproblem.egrad = constraints_grad{i};
%     checkgradient(newproblem);
% end

% x0 = problem.M.rand();
% x0 = zeros(size(problem.M.rand()));
% x0(Dim-dim+1:Dim ,1:dim) = eye(dim);
x0 = ones(Dim, rank)/sqrt(Dim);
options = [];

% xfinal = alm(problem, x0, options);
% xfinal = exactpenalty(problem, x0, options);
xfinal = logbarrier(problem, x0, options);

M = problem.M;
        figure
    subplot(2,3,1);
    surfprofile(problem, xfinal, M.randvec(xfinal), M.randvec(xfinal));
    subplot(2,3,2);
    surfprofile(problem, xfinal, M.randvec(xfinal), M.randvec(xfinal));
    subplot(2,3,3);
    surfprofile(problem, xfinal, M.randvec(xfinal), M.randvec(xfinal));
    subplot(2,3,4);
    surfprofile(problem, xfinal, M.randvec(xfinal), M.randvec(xfinal));
    subplot(2,3,5);
    surfprofile(problem, xfinal, M.randvec(xfinal), M.randvec(xfinal));
    subplot(2,3,6);
    surfprofile(problem, xfinal, M.randvec(xfinal), M.randvec(xfinal));

    what(A, xfinal);


    function val = costfun(u)
        val = trace((u.') * A * (u) );
    end

    function val = gradfun(u)
        val = A*u + A.'*u;
    end

end

function what(A, xfinal)
    check  = 1;
end
