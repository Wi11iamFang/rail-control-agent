% verify_layout.m - check StatusLabel does not overlap any button
addpath('D:\CREC_code\实践项目\RemoteDMIPrototype\src');

topology = RouteTopology.createLocalCandidate();
state = RemoteOperationState.initial(topology);
plant = MinimalTrainPlant();
ctx = RemoteOperationContext(topology, state, plant);
ctx.Driver = ShuntDriver(ctx);
g = GroundControlApp(ctx);

sl = g.StatusLabel.Position;       % [x y w h]
fprintf('StatusLabel: [%d %d %d %d]\n', round(sl));
overlapFound = false;
for k = 1:numel(g.Buttons)
    b = g.Buttons(k).Position;
    bx = [b(1) b(1)+b(3)]; by = [b(2) b(2)+b(4)];
    sx = [sl(1) sl(1)+sl(3)]; sy = [sl(2) sl(2)+sl(4)];
    ox = ~(bx(2) <= sx(1) || sx(2) <= bx(1));
    oy = ~(by(2) <= sy(1) || sy(2) <= by(1));
    if ox && oy
        fprintf('OVERLAP with button %d: [%d %d %d %d]\n', k, round(b));
        overlapFound = true;
    end
end
if ~overlapFound
    fprintf('NO overlap: StatusLabel no longer covers any button\n');
end
delete(g);
fprintf('LAYOUT_CHECK_DONE\n');