% verify_yard_banner.m - verify the new banner yard view exports a full-width scene
addpath('D:\CREC_code\实践项目\RemoteDMIPrototype\src');

topology = RouteTopology.createLocalCandidate();
state = RemoteOperationState.initial(topology);
plant = MinimalTrainPlant();
ctx = RemoteOperationContext(topology, state, plant);
driver = ShuntDriver(ctx); ctx.Driver = driver;

y = YardViewApp(ctx);
g = GroundControlApp(ctx);   % also exercise the shared renderer

% advance to signal-open state (locked route visible full width)
[~,~] = driver.takeover();
[~,~] = driver.requestRoute();
[~,~] = driver.checkRoute();
[~,~] = driver.lockRoute();
[~,~] = driver.openSignal();
pause(0.8);

outDir = 'D:\CREC_code\实践项目\RemoteDMIPrototype\outputs';
exportapp(y.UIFigure, fullfile(outDir, 'YardView_banner_signalopen.png'));
fprintf('exported signal-open banner OK\n');

[st,~] = driver.startMoving();
if strcmp(driver.RunTimer.Running,'on'), stop(driver.RunTimer); end
driver.SimDtPerTick = 1.0;
for k = 1:60, driver.tick(); end
pause(0.8);
exportapp(y.UIFigure, fullfile(outDir, 'YardView_banner_running.png'));
fprintf('exported running banner, pos=%.0f state=%s\n', ctx.State.positionM, ctx.State.scenarioState);

delete(g); delete(y);
fprintf('YARD_BANNER_DONE\n');