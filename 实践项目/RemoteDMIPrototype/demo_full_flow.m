% demo_full_flow.m - one-command full-flow demonstration.
% Drives the complete business flow on the shared context WITHOUT creating
% UI windows, so it is stable in batch and headless runs:
%   FAULT_STOPPED -> takeover -> route -> interlock -> lock -> signal
%   -> train runs -> stops -> stop confirm -> route release.
% Usage:
%   run('D:\CREC_code\实践项目\RemoteDMIPrototype\demo_full_flow.m')
%
% To watch the animation, run launch_RemoteDMIApp.m separately (three UI
% windows) and drive them with the buttons, or run make_gif.m for a GIF.

addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));

topology = RouteTopology.createLocalCandidate();
state = RemoteOperationState.initial(topology);
plant = MinimalTrainPlant();
ctx = RemoteOperationContext(topology, state, plant);
ctx.Driver = ShuntDriver(ctx);
driver = ctx.Driver;

fprintf('== 远程接管 ==\n');
[~, m] = driver.takeover(); fprintf('   %s\n', m);
pause(0.3);
fprintf('== 办理进路 ==\n');
[~, m] = driver.requestRoute(); fprintf('   %s\n', m);
pause(0.3);
fprintf('== 联锁检查 ==\n');
[~, m] = driver.checkRoute(); fprintf('   %s\n', m);
pause(0.3);
fprintf('== 锁闭进路 ==\n');
[~, m] = driver.lockRoute(); fprintf('   %s\n', m);
pause(0.3);
fprintf('== 开放信号 ==\n');
[~, m] = driver.openSignal(); fprintf('   %s\n', m);
pause(0.3);

fprintf('== 低速启动：车列沿进路转线 ==\n');
[~, m] = driver.startMoving(); fprintf('   %s\n', m);
if strcmp(driver.RunTimer.Running, 'on')
    stop(driver.RunTimer);   % drive ticks deterministically in this script
end
driver.SimDtPerTick = 1.0;

while ~strcmp(ctx.State.scenarioState, 'TARGET_BRAKING') || ctx.State.speedKmh > 0.05
    driver.tick();
    if ctx.State.speedKmh <= 0.05 && strcmp(ctx.State.scenarioState, 'TARGET_BRAKING')
        break;
    end
    pause(0.02);
end
fprintf('   stop: pos=%.0f m state=%s occ=%s dist=%.0f\n', ...
    ctx.State.positionM, ctx.State.scenarioState, ctx.State.currentTrack, ctx.State.targetDistanceM);
pause(0.3);

fprintf('== 停车确认 ==\n');
[~, m] = driver.stopConfirmed(); fprintf('   %s\n', m);
pause(0.3);
fprintf('== 进路解锁 ==\n');
[~, m] = driver.releaseRoute(); fprintf('   %s\n', m);
pause(0.3);

fprintf('DEMO_FULL_FLOW_DONE  pos=%.0f m state=%s route=%s signal=%s\n', ...
    ctx.State.positionM, ctx.State.scenarioState, ctx.State.routeState, ...
    ctx.State.signalAspect.XC21);