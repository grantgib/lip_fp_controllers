function [] = animate_lipm(info)
%% Extract Inputs
t = info.sol_info.t_traj;
x = cell2mat(info.sol_info.x_abs_traj);

xst = cell2mat(info.sol_info.xst_traj);
len = length(t);
iter_impact = cell2mat(info.sol_info.iter_impact_traj);

z_H = info.gait_info.z_H;

%% Initialize Figure
figure;
view(10,20);
hold on;
p_st = [xst(:,1); 0];
p_com = [x(1:2,1); z_H];
wd = 15;
sz_com = 5000;
sz_com_small = 10;
sz_st = 100;
alpha = 0.3;
gray = [0.5 0.5 0.5];
blue = [0 0.4470 0.7410];
green = [0.4660 0.6740 0.1880];
red = [0.6350 0.0780 0.1840];
yellow = [0.9290 0.6940 0.1250];
black = [0.1 0.1 0.1];
leg = line([p_st(1) p_com(1)],[p_st(2) p_com(2)],[p_st(3) p_com(3)],...
    'LineWidth',wd,...
    'Color',blue);

com = scatter3(p_com(1),p_com(2),p_com(3),...
    sz_com,red,'filled');
grid on;
axis([-5 5 -5 5 0 z_H+0.5])
xlabel('x [m]');
ylabel('y [m]');
zlabel('z [m]');
k = 1;

% inital transparent state
alpha_init = 0.6;
line([p_st(1) p_com(1)],[p_st(2) p_com(2)],[p_st(3) p_com(3)],...
    'LineWidth',wd,...
    'Color',[gray,alpha_init]);
scatter3(p_com(1),p_com(2),p_com(3),sz_com,gray,'filled',...
    'MarkerFaceAlpha',alpha_init)

%% Animate Figure
for i = 1:len
    p_st = [xst(:,i); 0];
    p_com = [x(1:2,i); z_H];
    set(leg,'XData',[p_st(1) p_com(1)],'YData',[p_st(2) p_com(2)],'ZData',[p_st(3) p_com(3)])
    set(com,'XData',p_com(1),'YData',p_com(2),'ZData',p_com(3));
    scatter3(p_com(1),p_com(2),p_com(3),sz_com_small,black,'filled')
    axis([-5+p_com(1) 5+p_com(1) -5+p_com(2) 5+p_com(2) 0 z_H+0.5])
    
    if i == iter_impact(k)+1
        line([p_st(1) p_com(1)],[p_st(2) p_com(2)],[p_st(3) p_com(3)],...
            'LineWidth',wd,...
            'Color',[blue,alpha]);
        scatter3(p_com(1),p_com(2),p_com(3),sz_com,red,'filled',...
            'MarkerFaceAlpha',alpha)
        scatter3(xst(1,i),xst(2,i),0,sz_st,green,'filled');
        k = k + 1;
    end
    
    drawnow;
    pause(0.01);
end




end
