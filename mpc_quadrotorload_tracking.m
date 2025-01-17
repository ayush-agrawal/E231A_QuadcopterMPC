%% 
% Code to implement MPC for trajectory tracking of quadrotor position

%% Setting up env
addpath(genpath([pwd, '/controllers/']));
addpath(genpath([pwd, '/gen/']));

%% Reset workspace
clear
clc
static_disp('');
close all
yalmip('clear')

%% Build quadrotor system
params = struct;
sys = Quadrotorload(params);

% actual quadrotor system: to simulate model uncertainty
act_sys = sys;
% uncomment the following to include model uncertainties


%% MPC params
% params
params.mpc.Tf = 10;
params.mpc.Ts = .1;
params.mpc.M = params.mpc.Tf/params.mpc.Ts;
params.mpc.N = 10;
% gains
params.mpc.Q = eye(sys.nDof);
params.mpc.R = 1*eye(sys.nAct);
params.mpc.P = params.mpc.Q;    

%% Load reference trajectory

% load('trajectory.mat');
% tref =  time(1):params.mpc.Ts:time(end);
% uref = [interp1(time',control',tref','spline')]';
% xref = [interp1(time',states',tref','linear')]';
% 
% figure
% plot(time,states(1,:),'r',tref,xref(1,:),'*b'); hold on
% plot(time,states(2,:),':r',tref,xref(2,:),'sb');
% figure;
% subplot(2,1,1);
% plot(time,control(1,:),'r',tref,uref(1,:),'b'); grid on;grid minor
% subplot(2,1,2);
% plot(time,control(2,:),'r',tref,uref(2,:),'b');grid on; grid minor

% fixed point reference trajectory
% --------------------------------
% waypoint = [1;1;0;0;0;0];
% xref = repmat(waypoint,1,(params.mpc.M+params.mpc.N));
% uref = (sys.mQ*sys.g/2)*ones(2,params.mpc.M+params.mpc.N);

% waypoints
% --------
% xref = [zeros(sys.nDof,floor(params.mpc.M/2)), repmat([5;5;0;0;0;0],1,params.mpc.M+params.mpc.N-floor(params.mpc.M/2))];
% uref = (sys.mQ*sys.g/2)*ones(2,params.mpc.M+params.mpc.N);

% [xref, uref] = generate_ref_trajectory(sys,params.mpc);

% circular trajectory
% -------------------
% tref = [0:params.mpc.Ts:params.mpc.Tf];
% xf = @(t) [sin(2*pi*0.01*t);0;0;0;0;0];
% xref = [];
% for i = 1:length(tref)
%     xref = [xref,xf(tref(i))];
% end
% uref = (sys.mQ*sys.g/2)*ones(2,params.mpc.M+params.mpc.N);

% diff-flat trajectory
% --------------------
tref = [0:params.mpc.Ts:params.mpc.Tf];
xref = [];
uref = [];
for i = 1:length(tref)
    [x_, u_] = generate_ref_trajectory(tref(i)  ,sys);
    xref = [xref,x_];
    uref = [uref,u_];
end
xref = [xref, repmat(xref(:,end),1,params.mpc.N)];
uref = [uref, repmat(uref(:,end),1,params.mpc.N)];

%% Initial condition
% x0 = [-1.5;-1.5;0;0;0;0];
x0  = xref(:,1);

%% Control 
% system response
sys_response.x = zeros(sys.nDof,params.mpc.M+1);
sys_response.u = zeros(sys.nAct,params.mpc.M);
sys_response.x(:,1) = x0;

% calculating input over the loop
for impc = 1:params.mpc.M
    fprintf('calculting input for T = %.4f\n',impc*params.mpc.Ts);
    
    %% optimizing for input
    xk = sys_response.x(:,impc);
    xrefk = xref(:,impc:(impc+params.mpc.N));
    urefk = uref(:,impc:(impc+params.mpc.N));
    
%     xrefk = [xref(:,impc), repmat(xref(:,impc+1),1,params.mpc.N)];
%     urefk = repmat(uref(:,impc),1,params.mpc.N+1);
    
    ctlk = solve_cftoc(params.mpc.Ts,xk,xrefk,urefk,sys,params);
    
    %% forward simulation
    f0 = act_sys.systemDynamics([],xrefk(:,1),urefk(:,1));
    [A,B] = act_sys.linearizeQuadrotor(xrefk(:,1),urefk(:,1));
    
    uk = ctlk.uOpt(:,1);
    dxk = f0 + A*(xk-xrefk(:,1)) + B*(uk-urefk(:,1));
    %
    sys_response.x(:,impc+1) = xk + params.mpc.Ts*dxk;
    sys_response.u(:,impc) = uk;
end


%% plots
time = 0:params.mpc.Ts:params.mpc.Tf;
figure
subplot(2,3,1);
plot(time', sys_response.x(1,:)');
title('y');
xlabel('time (s)');
ylabel('m');
grid on; grid minor;
subplot(2,3,2);
plot(time', sys_response.x(2,:)');
title('z');
xlabel('time (s)');
ylabel('m');
grid on; grid minor;
subplot(2,3,3);
plot(time', (180/pi)*sys_response.x(3,:)');
title('phi');
xlabel('time (s)');
ylabel('degrees');
grid on; grid minor;
subplot(2,3,4);
plot(time', sys_response.x(4,:)');
title('dy');
xlabel('time (s)');
ylabel('m/s');
grid on; grid minor;
subplot(2,3,5);
plot(time', sys_response.x(5,:)');
title('dz');
xlabel('time (s)');
ylabel('m/s');
grid on; grid minor;
subplot(2,3,6);
plot(time', sys_response.x(6,:)');
title('dphi');
xlabel('time (s)');
ylabel('rad/s');
grid on; grid minor;


figure;
plot(sys_response.x(1,:),sys_response.x(2,:),'r','linewidth',2);hold on;
plot(xref(1,:),xref(2,:),'b','linewidth',2);
legend('x','xref');
grid on; grid minor;
xlabel('Y');ylabel('Z');
title('output trajectory');

figure
plot(time(1:end-1), sys_response.u);
legend('F_1', 'F_2');
xlabel('time (s)');
ylabel('inputs');
grid on; grid minor;

keyboard;
%% Animate
opts.t = time';
opts.x = sys_response.x';
opts.td = time';
opts.xd = xref(:,1:params.mpc.M+1)';
opts.vid.MAKE_MOVIE = false;
sys.animateQuadrotor(opts);





