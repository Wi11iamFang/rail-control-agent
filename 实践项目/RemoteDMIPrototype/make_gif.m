% make_gif.m - render the shunting run as an animated GIF.
% Uses a plain (non-uifigure) figure so getframe works; YardViewRenderer
% draws into any axes, so the frames look identical to the big screen.
% Output: outputs/shunting_demo.gif
%
% Usage:
%   run('D:\CREC_code\实践项目\RemoteDMIPrototype\make_gif.m')

addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
outGif = fullfile(fileparts(mfilename('fullpath')), 'outputs', 'shunting_demo.gif');

topology = RouteTopology.createLocalCandidate();
state = RemoteOperationState.initial(topology);
plant = MinimalTrainPlant();
ctx = RemoteOperationContext(topology, state, plant);
driver = ShuntDriver(ctx);
ctx.Driver = driver;

% --- regular figure sized like the big screen (8:1 yard area) ---
f = figure('Color', [0.02 0.03 0.06], 'Position', [100 100 1440 420], ...
    'MenuBar', 'none', 'ToolBar', 'none', 'Name', '转线演示 GIF 录制');
ax = axes(f, 'Position', [0.03 0.18 0.94 0.74]);
renderer = YardViewRenderer(ax, topology);
renderer.SignalBlink = true;

% --- advance business to signal open ---
driver.takeover(); driver.requestRoute(); driver.checkRoute();
driver.lockRoute(); driver.openSignal();
renderer.update(ctx.State); drawnow; pause(0.2);

frameIdx = 0;
frameIdx = grabFrame(renderer, ctx, outGif, frameIdx);

% --- run to stop, grabbing frames ---
driver.startMoving();
if strcmp(driver.RunTimer.Running, 'on')
    stop(driver.RunTimer);
end
driver.SimDtPerTick = 1.0;
for i = 1:400
    driver.tick();
    if mod(i, 3) == 0
        frameIdx = grabFrame(renderer, ctx, outGif, frameIdx);
    end
    if ctx.State.speedKmh <= 0.05 && strcmp(ctx.State.scenarioState, 'TARGET_BRAKING')
        break;
    end
end
frameIdx = grabFrame(renderer, ctx, outGif, frameIdx);
fprintf('GIF frames=%d, pos=%.0f m state=%s\n', frameIdx, ctx.State.positionM, ctx.State.scenarioState);

% --- stop confirm + release (a few closing frames) ---
driver.stopConfirmed(); renderer.update(ctx.State); drawnow; pause(0.15);
frameIdx = grabFrame(renderer, ctx, outGif, frameIdx);
driver.releaseRoute(); renderer.update(ctx.State); drawnow; pause(0.15);
frameIdx = grabFrame(renderer, ctx, outGif, frameIdx);

close(f);
fprintf('MAKE_GIF_DONE -> %s (%d frames)\n', outGif, frameIdx);

function frameIdx = grabFrame(renderer, ctx, outGif, frameIdx)
    renderer.update(ctx.State);
    drawnow limitrate;
    fr = getframe(renderer.Ax.Parent);
    if size(fr.cdata, 3) == 3
        [im, cm] = rgb2ind(fr.cdata, 256);
    else
        im = fr.cdata; cm = gray(256);
    end
    if frameIdx == 0
        imwrite(im, cm, outGif, 'gif', 'Loopcount', inf, 'DelayTime', 0.10);
    else
        imwrite(im, cm, outGif, 'gif', 'WriteMode', 'append', 'DelayTime', 0.10);
    end
    frameIdx = frameIdx + 1;
end
