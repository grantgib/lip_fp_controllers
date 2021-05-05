function [info] = formulate_mpc_opti(info)
import casadi.*

%% Extract Inputs
% sym_info
g = info.sym_info.g;
m = info.sym_info.m;
n_x = info.sym_info.n_x;
k_slope = info.sym_info.k_slope;

% ctrl_info
dt = info.ctrl_info.mpc.dt;         % time interval
t_step = info.gait_info.t_step;     % step period
k_step = info.ctrl_info.mpc.k_step;
N_k = info.ctrl_info.mpc.N_k;
N_steps = info.ctrl_info.mpc.N_steps;
N_fp = info.ctrl_info.mpc.N_fp;
Q = info.ctrl_info.mpc.Q;
sol_type = info.ctrl_info.mpc.sol_type;

% gait_info
z_H = info.gait_info.z_H;

%% Dynamics
% Declare System Variables
xc = SX.sym('xc');  % relative position of center of mass w.r.t stance contact point
Lst = SX.sym('Lst');          % Angular momentum about contact point (stance foot)
x = [xc; Lst];

xdot = [...
    (Lst)/(m*z_H); % zc_dot would need to be estimated
    m*g*(xc)];     % lip model

% Continuous time dynamics
fc = Function('fc',{x},{xdot});   % f = dx/dt

% Discrete time dynamics
opts_intg = struct(...
    'tf',                           dt,...
    'simplify',                     true,...
    'number_of_finite_elements',    4);
dae = struct(...
    'x',    x,...
    'ode',  xdot);
intg = integrator('intg','rk',dae,opts_intg);
res = intg('x0',x);
x_next = res.xf;
fd = Function('fd',{x},{x_next});

%% Formulate Optimization Problem
opti = casadi.Opti();

% Initialize variables
n = 1;      % foot step iteration

% opt vars
X_traj = opti.variable(2,N_k);
Ufp_traj = opti.variable(1,N_fp);

% parameters
p_xcinit = opti.parameter(2,1);
p_xcdot_des = opti.parameter(1,1);
p_z_H = opti.parameter(1,1);
p_ufp_delta = opti.parameter(1,1);

% cost
opt_cost = cell(1,N_fp);

% initial conditions
Xk = X_traj(:,1);

% Loop through discrete trajectory
for k = 1:N_k-1
    k_init = (n-1)*k_step + 1;
    k_end = k_init + k_step-1;
    if (k == k_init)
        % init state of n-th step
        Xk_end = fd(Xk);
        Xk = X_traj(:,k+1);
    elseif (k == k_end)
        % add cost
        if n > 1 
            xdot_pseudo = Xk(2)/(m*p_z_H);
            opt_cost(n-1) = {(xdot_pseudo-p_xcdot_des)' * Q(n) * (xdot_pseudo-p_xcdot_des)};
        end
        Xk_end = fd(Xk);
        Xk_end = [Xk_end(1)-Ufp_traj(n); Xk_end(2)];     % update init position to reflect foot placement
        Xk = X_traj(:,k+1);
        n = n + 1;      % increase step counter
    else
        Xk_end = fd(Xk);
        Xk = X_traj(:,k+1);
    end
    opti.subject_to(Xk_end == Xk);
end
xdot_pseudo = Xk(2)/(m*p_z_H);
opt_cost(n-1) = {(xdot_pseudo-p_xcdot_des)' * Q(n) * (xdot_pseudo-p_xcdot_des)}; % add cost for velocity at end of prediction horizon

% initial condition constraint
opti.subject_to(X_traj(:,1) == p_xcinit);

% Rate limiter (only consider when there is more than one fp)
if N_fp > 1
    for n = 1:N_fp-1
        Ufp = Ufp_traj(n);
        Ufp_next = Ufp_traj(n+1);
        opti.subject_to(-p_ufp_delta <= Ufp_next - Ufp <= p_ufp_delta)
    end
end

% Combine cost, vars, constraints, parameters
opt_cost = sum(vertcat(opt_cost{:}));
opti.minimize(opt_cost);


%% Create an OPT solver
if sol_type == "qrqp"
    % C++ Code Generation
    opts = struct(...
        'qpsol',            'qrqp',...
        'print_header',     false,...
        'print_iteration',  false,...
        'print_time',       false);    % osqp, qrqp (not as robust joris says on google groups)
    opts.qpsol_options = struct(...
        'print_iter',       false,...
        'print_header',     false,...
        'print_info',       false);
    opti.solver('sqpmethod',opts);
    f_opti = opti.to_function('F_sqp',{p_xcinit,p_xcdot_des,p_z_H,p_ufp_delta},{Ufp_traj});


    
    % test
%     opti.set_value(p_xinit,[0.1;0])
%     opti.set_value(p_xcdot_des,0);
%     opti.set_value(p_z_H,0.8);
%     opti.set_value(p_ufp_delta,10);
%     sol = opti.solve();
%     xsol = sol.value(X_traj);
%     ufpsol = sol.value(Ufp_traj)
%     
%     ufpsol2 = full(F_sqp([0.1;0],0,0.8,10))
    
    % code generation
%     F_sqp.save('F_sqp.casadi');
%     F_sqp.generate('sqptest',struct('mex',true))
%     disp('Compiling...')
%     mex sqptest.c -DMATLAB_MEX_FILE
%     disp('done')
%     format long
end 
   

%% Return symbolics and solver
info.sym_info.fd = fd;
% info.ctrl_info.mpc.solver = solver;
info.ctrl_info.mpc.opti = opti;
info.ctrl_info.mpc.p_xcinit = p_xcinit;
info.ctrl_info.mpc.p_xcdot_des = p_xcdot_des;
info.ctrl_info.mpc.p_z_H = p_z_H;
info.ctrl_info.mpc.p_ufp_delta = p_ufp_delta;


