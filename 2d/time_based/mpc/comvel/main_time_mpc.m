% Planar Linear Inverted Pendulum Mode w/ COM velocity footplacement
clear; clc; close all;
restoredefaultpath;
addpath(genpath('utils/'));
addpath(genpath('/home/grantgib/workspace/toolbox/casadi-linux-matlabR2014b-v3.5.5'));
set(0,'DefaultFigureWindowStyle','docked');

%% Initialize Data Structures
% Higher level structure
info = struct(...
    'vis_info',     struct(),...
    'sym_info',     struct(),...
    'ctrl_info',    struct(),...
    'gait_info',    struct(),...
    'sol_info',     struct());

% Visualization info
info.vis_info = struct(...
    'plot', 1,...
    'anim', 1);

% Symbolic variables
info.sym_info = struct(...
    'n_x',      2,...
    'g',        9.81);

% Gait parameters
info.gait_info = struct(...
    'phase_type',           "time",... time
    'x_init',               [0.2;1],...
    'z_const',              1,...
    't_step',               0.4,...
    'x_stance',             0,...
    'xdot_com_des',         2,...
    'num_steps',            10,...
    'num_steps_change_vel', inf,...
    'increase_vel',         false,...
    'decrease_vel',         true);

% Control parameters
info.ctrl_info.type = "mpc";
%   mpc
dt = 0.005;
k_step =  info.gait_info.t_step / dt;
N_steps_ahead = 3;
N_steps = N_steps_ahead + 1;    % first step is predetermined by init; number of discontinuous trajectories, 
N_fp = N_steps - 1;  % #fp = #N_steps - 1   
N_k = N_steps * k_step;
q = 10;     % cost
for i = 1:N_steps
    Q(i) = q^i;     % increase exponentially for each step
end
info.ctrl_info.mpc = struct(...
    'x_min',            [-inf; -inf],...
    'x_max',            [inf; inf],...
    'ufp',              false,...
    'ufp_max',          inf,...
    'ufp_min',          -inf,...
    'ufp_delta',        inf,...
    'dt',               dt,...
    'k_step',           k_step,...
    'N_steps_ahead',    N_steps_ahead,...
    'N_steps',          N_steps,...
    'N_k',              N_k,...
    'N_fp',             N_fp,...
    'Q',                Q);
      
% Solution stuct
info.sol_info = struct();

%% Formulate Optimization
disp("Formulating Optimization...");
info = formulate_mpc(info);
disp("Optimization Solver Created!");
% test_solver(); % test solver

%% Initialize Gait/Simulation Parameters
disp("Simulating...");
info = simulate_lipm_mpc(info);
disp("Simulation Complete");

%% Visualization
% Plot
if info.vis_info.plot
    plot_lipm(info);
end

% Animate
if info.vis_info.anim
    animate_lipm(info)
end

