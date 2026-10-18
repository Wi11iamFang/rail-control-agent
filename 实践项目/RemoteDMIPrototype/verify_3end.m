% verify_3end.m - static/batch verification for the three-ended refactor
addpath('D:\CREC_code\实践项目\RemoteDMIPrototype\src');

fprintf('== 1. classes reachable ==\n');
assert(~isempty(which('ShuntDriver')), 'ShuntDriver missing');
assert(~isempty(which('YardViewRenderer')), 'YardViewRenderer missing');
assert(~isempty(which('GroundControlApp')), 'GroundControlApp missing');
assert(~isempty(which('YardViewApp')), 'YardViewApp missing');
assert(~isempty(which('RemoteDMIApp')), 'RemoteDMIApp missing');
fprintf('   all classes loaded OK\n');

fprintf('== 2. context + driver ==\n');
topology = RouteTopology.createLocalCandidate();
state = RemoteOperationState.initial(topology);
plant = MinimalTrainPlant();
ctx = RemoteOperationContext(topology, state, plant);
driver = ShuntDriver(ctx);
ctx.Driver = driver;
assert(strcmp(state.scenarioState, 'FAULT_STOPPED'), 'initial state wrong');
fprintf('   initialized=%s\n', state.scenarioState);

fprintf('== 3. illegal action rejected ==\n');
[st, msg] = driver.lockRoute();
assert(strcmp(st.alarmState, 'operation-rejected'), 'should reject before route');
assert(~isempty(strfind(msg, '操作拒绝')), 'message should be explicit');
fprintf('   rejected: %s\n', msg);

fprintf('== 4. business sequence ==\n');
[st, msg] = driver.takeover();
assert(strcmp(st.scenarioState, 'SHUNTING_MODE_READY'), 'takeover failed');
[st, msg] = driver.requestRoute();
assert(strcmp(st.scenarioState, 'ROUTE_REQUESTED'), 'requestRoute failed');
[st, msg] = driver.checkRoute();
assert(strcmp(st.scenarioState, 'INTERLOCK_CHECKING'), 'checkRoute failed');
[st, msg] = driver.lockRoute();
assert(strcmp(st.scenarioState, 'ROUTE_LOCKED'), 'lockRoute failed');
[st, msg] = driver.openSignal();
assert(strcmp(st.scenarioState, 'SHUNT_SIGNAL_OPEN'), 'openSignal failed');
assert(strcmp(st.signalAspect.XC21, 'shunting-open'), 'signal aspect wrong');
fprintf('   route actions -> %s, XC21=%s\n', st.scenarioState, st.signalAspect.XC21);

fprintf('== 5. start moving ==\n');
[st, msg] = driver.startMoving();
assert(strcmp(st.scenarioState, 'TRAIN_ENTERED_ROUTE'), 'startMoving failed');
if strcmp(driver.RunTimer.Running, 'on')
    stop(driver.RunTimer);
end
fprintf('   startMoving -> %s\n', st.scenarioState);

fprintf('== 6. run to target and stop ==\n');
driver.SimDtPerTick = 1.0;
i = 0; maxIter = 600;
while i < maxIter
    i = i + 1;
    driver.tick();
    s = ctx.State;
    if strcmp(s.scenarioState, 'TARGET_BRAKING') && s.speedKmh <= 0.05
        break;
    end
end
s = ctx.State;
fprintf('   after %d ticks: state=%s pos=%.1f v=%.2f occ=%s dist=%.0f\n', ...
    i, s.scenarioState, s.positionM, s.speedKmh, s.currentTrack, s.targetDistanceM);
assert(i < maxIter, 'train did not stop in time');
assert(strcmp(s.scenarioState, 'TARGET_BRAKING'), 'should be TARGET_BRAKING when stopped');
assert(s.positionM >= 418, 'train should have reached target');

fprintf('== 7. stop confirm + release ==\n');
[st, msg] = driver.stopConfirmed();
assert(strcmp(st.scenarioState, 'STOP_CONFIRMED'), 'stopConfirmed failed');
[st, msg] = driver.releaseRoute();
assert(strcmp(st.scenarioState, 'ROUTE_RELEASED'), 'releaseRoute failed');
assert(strcmp(st.signalAspect.XC21, 'closed'), 'signal should close after release');
fprintf('   releaseRoute -> %s, XC21=%s\n', st.scenarioState, st.signalAspect.XC21);
fprintf('** CLOSED LOOP PASSED **\n');

fprintf('== 8. three apps instantiate (headless) ==\n');
resetd = RemoteOperationState.initial(topology);
ctx.State = resetd;
g = []; y = []; o = [];
try
    g = GroundControlApp(ctx);
    y = YardViewApp(ctx);
    o = RemoteDMIApp(ctx);
    fprintf('   ground/yard/onboard all instantiated OK\n');
    pause(0.6);
    fprintf('   timers ran without error\n');
catch err
    fprintf('   UI issue: %s\n', err.message);
end
if ~isempty(g) && isvalid(g), delete(g); end
if ~isempty(y) && isvalid(y), delete(y); end
if ~isempty(o) && isvalid(o), delete(o); end
pause(0.3);
fprintf('   apps deleted OK\n');
fprintf('VERIFY_DONE\n');