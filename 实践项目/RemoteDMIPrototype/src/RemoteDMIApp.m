classdef RemoteDMIApp < matlab.apps.AppBase
    % RemoteDMIApp
    % 展示型 DMI 主界面原型：按司机操作手册图 5/图 6 布局绘制，
    % 内置轻量交互演示，不接入远程调车控制区和外部仿真设备。

    properties (Access = public)
        UIFigure matlab.ui.Figure
        MainPanel matlab.ui.container.Panel
        SpeedAxes matlab.ui.control.UIAxes
        PlanAxes matlab.ui.control.UIAxes
        DistanceAxes matlab.ui.control.UIAxes
        StatusAxes matlab.ui.control.UIAxes
        LocalMapAxes matlab.ui.control.UIAxes
        MessageArea matlab.ui.control.TextArea
    end

    properties (Access = private)
        C = struct()
        DemoTimer
        Buttons = {}
        IsRunning = false
        Blink = false
        Speed = 79
        PermittedSpeed = 160
        TrainX = 6.2
        TargetDistance = 610
        KmMeter = 54.751
        ModeText = 'AM'
        StationName = '梅宋头东'
        TrainNo = 'D2'
        DoorHint = '双侧'
        BrakeText = '缓解'
        ControlText = '机控'
        MessageLog = {}
        Plant
        DemoPhase = 0
        PhaseElapsed = 0
        TargetPositionM = 420
        Notch = 0
        ServiceBrake = false
        EmergencyBrake = false
        RouteState = '未建立'
        SwitchState = '定位'
        TrackState = 'A股道'
        ScenarioState = '故障停车'
        LastPhaseAnnounced = -1
        Topology
        SharedState
        LocalMapImage
    end

    methods (Access = private)
        function startup(app)
            app.C.bg = [0.02 0.025 0.03];
            app.C.grid = [0.14 0.20 0.38];
            app.C.blue = [0.00 0.14 0.95];
            app.C.white = [0.92 0.96 1.00];
            app.C.dim = [0.46 0.55 0.62];
            app.C.yellow = [1.00 0.94 0.18];
            app.C.green = [0.12 0.95 0.08];
            app.C.orange = [1.00 0.62 0.12];
            app.C.red = [1.00 0.12 0.08];
            app.C.gray = [0.34 0.36 0.37];

            app.MessageLog = { ...
                '17:11:36  故障停车，等待远程接管'; ...
                '17:11:11  车载ATO退出自动驾驶'; ...
                '17:09:56  ATP保持制动'; ...
                '17:09:46  当前股道：A股道'};
            app.Topology = RouteTopology.createLocalCandidate();
            app.SharedState = RemoteOperationState.initial(app.Topology);
            app.Plant = MinimalTrainPlant();
            app.resetScenario();

            app.createComponents();
            app.refreshAll();

            app.DemoTimer = timer( ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', 0.25, ...
                'TimerFcn', @(~, ~) app.onTick());
        end

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'DMI 主界面仿真 - 展示交互版';
            app.UIFigure.Color = app.C.bg;
            app.UIFigure.Position = [100 80 1024 768];
            app.UIFigure.Resize = 'off';

            app.MainPanel = uipanel(app.UIFigure);
            app.MainPanel.BorderType = 'line';
            app.MainPanel.BackgroundColor = app.C.bg;
            app.MainPanel.Position = [28 28 968 712];

            app.SpeedAxes = uiaxes(app.MainPanel);
            app.SpeedAxes.Position = [54 330 370 330];
            app.prepareAxes(app.SpeedAxes, [-1.2 1.2], [-1.1 1.15]);

            app.PlanAxes = uiaxes(app.MainPanel);
            app.PlanAxes.Position = [446 270 382 390];
            app.prepareAxes(app.PlanAxes, [0 16], [0 320]);

            app.DistanceAxes = uiaxes(app.MainPanel);
            app.DistanceAxes.Position = [54 170 105 170];
            app.prepareAxes(app.DistanceAxes, [0 1], [0 1000]);

            app.StatusAxes = uiaxes(app.MainPanel);
            app.StatusAxes.Position = [515 52 330 208];
            app.prepareAxes(app.StatusAxes, [0 330], [0 208]);

            app.LocalMapAxes = uiaxes(app.MainPanel);
            app.LocalMapAxes.Position = [54 8 790 118];
            app.prepareAxes(app.LocalMapAxes, [1 1423], [1 177]);
            app.LocalMapAxes.XLim = [1 1423];
            app.LocalMapAxes.YLim = [1 177];
            app.LocalMapAxes.YDir = 'reverse';
            app.LocalMapAxes.Visible = 'on';

            app.MessageArea = uitextarea(app.MainPanel);
            app.MessageArea.Position = [175 52 330 128];
            app.MessageArea.BackgroundColor = [0.02 0.025 0.025];
            app.MessageArea.FontColor = app.C.white;
            app.MessageArea.FontName = 'Microsoft YaHei UI';
            app.MessageArea.FontSize = 15;

            app.drawFunctionKeys();
        end

        function prepareAxes(app, ax, xlimv, ylimv)
            ax.Color = app.C.bg;
            ax.XColor = 'none';
            ax.YColor = 'none';
            ax.Toolbar.Visible = 'off';
            ax.Interactions = [];
            ax.XLim = xlimv;
            ax.YLim = ylimv;
            ax.NextPlot = 'add';
            axis(ax, 'manual');
        end

        function refreshAll(app)
            app.drawSpeedometer();
            app.drawPlanArea();
            app.drawLocalMap();
            app.drawDistanceAndStatus();
            app.drawBottomStatus();
            app.refreshMessages();
            app.refreshButtons();
            drawnow limitrate;
        end

        function drawSpeedometer(app)
            ax = app.SpeedAxes;
            cla(ax);
            rectangle(ax, 'Position', [-1.16 -1.04 2.32 2.10], ...
                'Curvature', 0.08, 'FaceColor', app.C.bg, ...
                'EdgeColor', [0.15 0.18 0.20], 'LineWidth', 1.5);

            theta0 = 225;
            theta1 = -45;
            for v = 0:25:400
                t = deg2rad(theta0 + (theta1 - theta0) * v / 400);
                isMajor = mod(v, 50) == 0;
                r1 = 0.83;
                r2 = 0.98;
                lw = 1.2;
                if isMajor
                    r1 = 0.76;
                    lw = 2.2;
                end
                plot(ax, [r1*cos(t) r2*cos(t)], [r1*sin(t) r2*sin(t)], ...
                    'Color', app.C.white, 'LineWidth', lw);
                if isMajor
                    text(ax, 0.62*cos(t), 0.62*sin(t), sprintf('%d', v), ...
                        'Color', app.C.white, 'FontSize', 15, 'FontWeight', 'bold', ...
                        'HorizontalAlignment', 'center', 'FontName', 'Microsoft YaHei UI');
                end
            end

            app.drawArc(ax, 0.99, theta0, theta1, app.C.white, 4);
            app.drawArc(ax, 0.86, theta0, theta0 + (theta1 - theta0) * app.PermittedSpeed / 400, app.C.blue, 7);

            needleTheta = deg2rad(theta0 + (theta1 - theta0) * app.Speed / 400);
            plot(ax, [0 0.72*cos(needleTheta)], [0 0.72*sin(needleTheta)], ...
                'Color', app.C.white, 'LineWidth', 6);
            scatter(ax, 0, 0, 2200, app.C.white, 'filled', ...
                'MarkerEdgeColor', [0.75 0.90 1.00], 'LineWidth', 2);
            text(ax, 0, 0, sprintf('%d', round(app.Speed)), ...
                'Color', [0.36 0.48 0.72], 'FontSize', 24, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
            text(ax, -0.98, -0.83, 'CTCS2', 'Color', app.C.white, ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI');
        end

        function drawArc(~, ax, radius, thetaStart, thetaEnd, color, width)
            theta = linspace(deg2rad(thetaStart), deg2rad(thetaEnd), 140);
            plot(ax, radius*cos(theta), radius*sin(theta), 'Color', color, 'LineWidth', width);
        end

        function drawPlanArea(app)
            ax = app.PlanAxes;
            cla(ax);
            rectangle(ax, 'Position', [0 0 16 320], ...
                'FaceColor', [0.02 0.03 0.09], 'EdgeColor', [0.18 0.25 0.42], 'LineWidth', 1.2);

            for x = 0:1:16
                plot(ax, [x x], [0 320], 'Color', app.C.grid, 'LineWidth', 0.8);
            end
            for y = 0:50:300
                plot(ax, [0 16], [y y], 'Color', app.C.grid, 'LineWidth', 0.8);
                text(ax, -0.45, y, sprintf('%d', y), 'Color', app.C.white, ...
                    'FontSize', 10, 'HorizontalAlignment', 'right');
            end

            fill(ax, [0 0 5.3 6.5 16 16], [0 145 145 90 90 0], ...
                app.C.blue, 'FaceAlpha', 0.82, 'EdgeColor', 'none');
            if app.Speed > app.PermittedSpeed
                mrspColor = app.C.orange;
            else
                mrspColor = app.C.yellow;
            end
            plot(ax, [0 4 6 10 16], [170 170 130 120 120], 'Color', mrspColor, 'LineWidth', 3);

            cursorColor = app.C.yellow;
            if app.Blink && app.Speed > app.PermittedSpeed
                cursorColor = app.C.red;
            end
            plot(ax, [app.TrainX app.TrainX], [0 300], 'Color', cursorColor, 'LineWidth', 3);
            plot(ax, [0 16], [35 35], 'Color', app.C.white, 'LineWidth', 8);
            plot(ax, [7.8 7.8], [24 48], 'Color', app.C.white, 'LineWidth', 10);
            plot(ax, [12.5 12.5], [20 55], 'Color', app.C.white, 'LineWidth', 4);
            plot(ax, [6.8 9.4], [35 78], 'Color', app.C.white, 'LineWidth', 5);
            if any(strcmp(app.TrackState, {'道岔区','B股道'}))
                plot(ax, [6.8 9.4], [35 78], 'Color', app.C.yellow, 'LineWidth', 3);
            end

            text(ax, 0.1, -22, '0', 'Color', app.C.white, 'FontSize', 11);
            text(ax, 4, -22, '4', 'Color', app.C.white, 'FontSize', 11, 'HorizontalAlignment', 'center');
            text(ax, 8, -22, '8k', 'Color', app.C.white, 'FontSize', 11, 'HorizontalAlignment', 'center');
            text(ax, 12, -22, '12k', 'Color', app.C.white, 'FontSize', 11, 'HorizontalAlignment', 'center');
            text(ax, 16, -22, '16k', 'Color', app.C.white, 'FontSize', 11, 'HorizontalAlignment', 'right');

            signalColor = app.C.green;
            if app.Speed > app.PermittedSpeed
                signalColor = app.C.orange;
            end
            rectangle(ax, 'Position', [0.1 266 1.1 38], 'FaceColor', signalColor, ...
                'Curvature', [1 1], 'EdgeColor', signalColor * 0.8, 'LineWidth', 1.8);
            text(ax, 13.6, 232, '0', 'Color', app.C.white, 'FontSize', 18, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center');
            text(ax, 13.6, 205, char(9661), 'Color', app.C.white, 'FontSize', 22, ...
                'HorizontalAlignment', 'center');
            text(ax, 1.2, 18, 'II', 'Color', app.C.white, 'FontSize', 16, 'FontWeight', 'bold');
            text(ax, 8.3, 18, 'I', 'Color', app.C.white, 'FontSize', 16, 'FontWeight', 'bold');
            text(ax, 0.8, 310, '速度信息 / 运行计划', 'Color', app.C.dim, ...
                'FontSize', 13, 'FontName', 'Microsoft YaHei UI');
            text(ax, 0.8, 292, ['流程：' app.ScenarioState], 'Color', app.C.white, ...
                'FontSize', 13, 'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI');
            text(ax, 0.8, 274, ['进路：' app.RouteState '  道岔S1：' app.SwitchState], ...
                'Color', app.C.white, 'FontSize', 11, 'FontName', 'Microsoft YaHei UI');
            text(ax, 10.3, 70, app.TrackState, 'Color', app.C.white, 'FontSize', 12, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI');
        end

        function drawLocalMap(app)
            ax = app.LocalMapAxes;
            cla(ax);
            imagePath = app.Topology.imagePath;
            if exist(imagePath, 'file') ~= 2
                text(ax, 20, 90, '局部线路图未找到', 'Color', app.C.red, ...
                    'FontName', 'Microsoft YaHei UI', 'FontSize', 12);
                return;
            end
            img = imread(imagePath);
            image(ax, 'CData', img, 'XData', [1 size(img, 2)], ...
                'YData', [size(img, 1) 1]);
            ax.XLim = [1 size(img, 2)];
            ax.YLim = [1 size(img, 1)];
            ax.YDir = 'reverse';
            ax.XTick = [];
            ax.YTick = [];
            ax.Layer = 'top';

            g = app.Topology.displayGeometry;
            route = app.Topology.routes(1);
            routePoints = [];
            for k = 1:numel(route.sections)
                sectionId = route.sections{k};
                if isfield(g.sections, sectionId)
                    points = g.sections.(sectionId);
                    if isempty(routePoints)
                        routePoints = points;
                    else
                        routePoints = [routePoints; points(2:end, :)]; %#ok<AGROW>
                    end
                end
            end
            if ~isempty(routePoints)
                plot(ax, routePoints(:, 1), routePoints(:, 2), ...
                    'Color', app.C.yellow, 'LineWidth', 2.5);
                trainPoint = app.routePoint(routePoints, app.Plant.PositionM);
                scatter(ax, trainPoint(1), trainPoint(2), 48, app.C.red, ...
                    'filled', 'MarkerEdgeColor', app.C.white, 'LineWidth', 1.2);
            end

            if isfield(g.signals, route.startSignal)
                p = g.signals.(route.startSignal);
                scatter(ax, p(1), p(2), 34, app.C.green, 'filled', ...
                    'MarkerEdgeColor', app.C.white);
            end
            if isfield(g.labels, 'D20_APPROACH')
                p = g.labels.D20_APPROACH;
                text(ax, p(1), p(2), '候选目标段', 'Color', app.C.yellow, ...
                    'FontSize', 9, 'FontName', 'Microsoft YaHei UI');
            end
            text(ax, 8, 14, '局部图：PNG底图 / 候选进路叠加', ...
                'Color', app.C.white, 'FontSize', 9, ...
                'BackgroundColor', [0.02 0.03 0.09], ...
                'Margin', 2, 'FontName', 'Microsoft YaHei UI');
        end

        function point = routePoint(~, points, positionM)
            if isempty(points)
                point = [NaN NaN];
                return;
            end
            d = sqrt(sum(diff(points, 1, 1).^2, 2));
            cumulative = [0; cumsum(d)];
            if cumulative(end) <= 0
                point = points(1, :);
                return;
            end
            q = min(max(positionM / 420 * cumulative(end), 0), cumulative(end));
            x = interp1(cumulative, points(:, 1), q, 'linear');
            y = interp1(cumulative, points(:, 2), q, 'linear');
            point = [x y];
        end

        function drawDistanceAndStatus(app)
            ax = app.DistanceAxes;
            cla(ax);
            rectangle(ax, 'Position', [0.12 0 0.76 1000], ...
                'FaceColor', [0.10 0.10 0.10], 'EdgeColor', app.C.dim);
            fill(ax, [0.12 0.88 0.88 0.12], [0 0 app.TargetDistance app.TargetDistance], ...
                [0.86 0.60 0.32], 'EdgeColor', 'none', 'FaceAlpha', 0.88);
            text(ax, 0.50, 945, 'A1', 'Color', app.C.white, 'FontSize', 13, ...
                'HorizontalAlignment', 'center');
            numberY = min(950, max(610, app.TargetDistance + 45));
            text(ax, 0.50, numberY, sprintf('%d', round(app.TargetDistance)), ...
                'Color', app.C.white, 'FontSize', 18, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center');
            text(ax, 0.50, 330, '目标', 'Color', app.C.white, 'FontSize', 15, ...
                'HorizontalAlignment', 'center', 'FontName', 'Microsoft YaHei UI');
            text(ax, 0.50, 270, '距离', 'Color', app.C.white, 'FontSize', 15, ...
                'HorizontalAlignment', 'center', 'FontName', 'Microsoft YaHei UI');

            app.addStatusLabel([54 132 80 26], 'CTCS 2', app.C.white, app.C.bg);
            brakeColor = [0.06 0.15 0.22];
            if strcmp(app.BrakeText, '制动')
                brakeColor = [0.55 0.12 0.08];
            end
            app.addStatusLabel([54 100 80 26], app.BrakeText, app.C.white, brakeColor);
            app.addStatusLabel([54 68 80 26], app.ControlText, app.C.white, app.C.bg);
        end

        function drawBottomStatus(app)
            ax = app.StatusAxes;
            cla(ax);
            text(ax, 18, 190, app.ModeText, 'Color', app.C.white, 'FontSize', 14, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');
            plot(ax, 45:13:156, 190 * ones(1, 9), '.', 'Color', app.C.white, 'MarkerSize', 7);

            app.drawAtoTrainIcon(ax, 18, 142);
            text(ax, 52, 145, 'A', 'Color', app.C.white, 'FontSize', 44, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');
            app.drawArrowIcon(ax, 52, 94, 'up', app.C.white);
            app.drawArrowIcon(ax, 52, 34, 'down', app.C.white);

            text(ax, 92, 79, '车次号', 'Color', app.C.white, 'FontSize', 12, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI');
            text(ax, 100, 62, app.TrainNo, 'Color', app.C.white, 'FontSize', 13, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI');
            text(ax, 185, 158, app.StationName, 'Color', app.C.white, 'FontSize', 14, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');

            text(ax, 142, 112, 'P', 'Color', app.C.white, 'FontSize', 34, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');
            text(ax, 160, 108, 'L', 'Color', app.C.white, 'FontSize', 24, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');
            app.drawDoorIcon(ax, 188, 114);
            text(ax, 224, 125, 'A', 'Color', app.C.white, 'FontSize', 28, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');
            text(ax, 247, 102, 'T', 'Color', app.C.white, 'FontSize', 30, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');

            app.drawNetworkIcon(ax, 166, 56);
            app.drawMagnifierIcon(ax, 222, 53, '+');
            app.drawMagnifierIcon(ax, 265, 53, '-');
            t = datetime('now');
            text(ax, 312, 86, '时间日期', 'Color', app.C.white, 'FontSize', 10, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');
            text(ax, 312, 68, datestr(t, 'HH:MM:SS'), 'Color', app.C.white, 'FontSize', 10, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');
            text(ax, 312, 50, datestr(t, 'yy-mm-dd'), 'Color', app.C.white, 'FontSize', 10, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', 'HorizontalAlignment', 'center');
            app.addStatusLabel([230 20 130 28], sprintf('K%02d+%03d', floor(app.KmMeter), round(mod(app.KmMeter, 1) * 1000)), ...
                app.C.white, app.C.bg, 17);
        end

        function drawFunctionKeys(app)
            labels = {'数据','模式','载频','等级','其他','启动','缓解','警惕'};
            app.Buttons = cell(1, numel(labels));
            top = 646;
            keyH = 70;
            for k = 1:numel(labels)
                y = top - (k - 1) * keyH;
                btn = uibutton(app.MainPanel, 'push');
                btn.Position = [850 y 88 60];
                btn.Text = labels{k};
                btn.FontName = 'Microsoft YaHei UI';
                btn.FontSize = 17;
                btn.FontWeight = 'bold';
                btn.FontColor = app.C.white;
                btn.BackgroundColor = [0.13 0.17 0.24];
                btn.ButtonPushedFcn = @(~, ~) app.onFunctionKey(k);
                app.Buttons{k} = btn;
            end
        end

        function refreshButtons(app)
            for k = 1:numel(app.Buttons)
                app.Buttons{k}.BackgroundColor = [0.13 0.17 0.24];
            end
            if app.IsRunning
                app.Buttons{6}.Text = '暂停';
                app.Buttons{6}.BackgroundColor = [0.05 0.32 0.18];
            else
                app.Buttons{6}.Text = '启动';
            end
            if strcmp(app.BrakeText, '缓解')
                app.Buttons{7}.BackgroundColor = [0.06 0.22 0.32];
            end
            if app.Speed > app.PermittedSpeed
                app.Buttons{8}.BackgroundColor = app.C.orange;
            end
        end

        function onFunctionKey(app, keyIndex)
            switch keyIndex
                case 1
                    app.pushMessage(sprintf('数据：%s，速度%.1fkm/h，目标距离%.0fm', ...
                        app.TrackState, app.Speed, app.TargetDistance));
                case 2
                    app.ModeText = '调车';
                    app.pushMessage('切换模式：调车模式');
                case 3
                    app.pushMessage('载频菜单：上行 / 下行切换演示');
                case 4
                    app.pushMessage('等级菜单：CTCS-2');
                case 5
                    app.ControlText = app.toggleText(app.ControlText, '机控', '人控');
                    app.pushMessage(['控制优先级：' app.ControlText]);
                case 6
                    app.toggleDemo();
                case 7
                    app.BrakeText = '缓解';
                    app.Speed = max(0, app.Speed - 18);
                    app.pushMessage('允许缓解，制动状态复位');
                case 8
                    app.Speed = min(60, app.Speed + 18);
                    app.BrakeText = '制动';
                    app.ServiceBrake = true;
                    app.pushMessage('警惕确认：制动提示演示');
            end
            app.refreshAll();
        end

        function toggleDemo(app)
            if app.IsRunning
                stop(app.DemoTimer);
                app.IsRunning = false;
                app.pushMessage('远程调车演示暂停');
            else
                if app.DemoPhase == 0 || strcmp(app.ScenarioState, '换线完成')
                    app.resetScenario();
                end
                start(app.DemoTimer);
                app.IsRunning = true;
                app.pushMessage('远程接管流程启动');
            end
        end

        function onTick(app)
            app.Blink = ~app.Blink;
            dt = 0.25;
            app.PhaseElapsed = app.PhaseElapsed + dt;
            app.updateScenarioPhase();

            state = app.Plant.step(app.Notch, app.ServiceBrake, app.EmergencyBrake, dt);
            app.Speed = min(220, state.speedKmh);
            app.TargetDistance = max(0, app.TargetPositionM - state.positionM);
            app.TrainX = min(15.2, 1.0 + state.positionM / app.TargetPositionM * 13.4);
            app.KmMeter = 54.751 + state.positionM / 1000;

            if app.Speed > app.PermittedSpeed + 1
                app.BrakeText = '制动';
            elseif strcmp(app.BrakeText, '制动') && app.Speed < app.PermittedSpeed - 8
                app.BrakeText = '缓解';
            end
            app.syncSharedState(state);
            if strcmp(app.ScenarioState, '换线完成')
                stop(app.DemoTimer);
                app.IsRunning = false;
            end
            app.refreshAll();
        end

        function syncSharedState(app, plantState)
            % Publish legacy demo values into the shared candidate state.
            app.SharedState.speedKmh = app.Speed;
            app.SharedState.positionM = plantState.positionM;
            app.SharedState.accelerationMps2 = plantState.accelerationMps2;
            app.SharedState.mode = app.ModeText;
            app.SharedState.routeState = app.RouteState;
            app.SharedState.brakeState = app.BrakeText;
            app.SharedState.targetDistanceM = app.TargetDistance;
            app.SharedState.timestamp = datetime('now');

            if app.DemoPhase >= 3
                app.SharedState.scenarioState = 'SHUNT_SIGNAL_OPEN';
                app.SharedState.signalAspect.XC21 = 'shunting-open';
                app.SharedState.routeState = 'signal-open';
            end
            if app.DemoPhase >= 7
                app.SharedState.scenarioState = 'STOP_CONFIRMED';
                app.SharedState.signalAspect.XC21 = 'closed';
            end

            route = app.Topology.routes(1);
            if plantState.positionM < 210
                sectionIndex = 1;
            elseif plantState.positionM < 285
                sectionIndex = 2;
            elseif plantState.positionM < 335
                sectionIndex = 3;
            else
                sectionIndex = 4;
            end
            app.SharedState = RemoteOperationState.updateTrackOccupancy( ...
                app.SharedState, app.Topology, sectionIndex);
            if app.DemoPhase == 0
                app.SharedState.scenarioState = 'FAULT_STOPPED';
            elseif app.DemoPhase == 1
                app.SharedState.scenarioState = 'REMOTE_TAKEOVER';
            elseif app.DemoPhase == 2
                app.SharedState.scenarioState = 'ROUTE_REQUESTED';
            elseif app.DemoPhase == 3
                app.SharedState.scenarioState = 'ROUTE_LOCKED';
            end
            app.SharedState.currentTrack = route.sections{sectionIndex};
        end

        function resetScenario(app)
            app.DemoPhase = 0;
            app.PhaseElapsed = 0;
            app.LastPhaseAnnounced = -1;
            app.TargetPositionM = 420;
            app.Notch = 0;
            app.ServiceBrake = true;
            app.EmergencyBrake = false;
            app.RouteState = '未建立';
            app.SharedState = RemoteOperationState.initial(app.Topology);
            app.SwitchState = '定位';
            app.TrackState = 'A股道';
            app.ScenarioState = '故障停车';
            app.ModeText = '待机';
            app.BrakeText = '制动';
            app.ControlText = '机控';
            app.PermittedSpeed = 40;
            app.TargetDistance = app.TargetPositionM;
            app.TrainX = 1.0;
            app.Speed = 0;
            app.KmMeter = 54.751;
            if ~isempty(app.Plant)
                app.Plant.reset(0);
            end
        end

        function updateScenarioPhase(app)
            pos = app.Plant.PositionM;
            v = app.Plant.VelocityMps;

            if app.DemoPhase == 0 && app.PhaseElapsed >= 0.75
                app.enterPhase(1, '远程接管', '地面端取得远程接管权限');
            elseif app.DemoPhase == 1 && app.PhaseElapsed >= 1.25
                app.enterPhase(2, '请求进路', '请求A股道至B股道调车进路');
            elseif app.DemoPhase == 2 && app.PhaseElapsed >= 1.25
                app.enterPhase(3, '道岔锁闭', 'S1道岔反位锁闭，进路授权');
            elseif app.DemoPhase == 3 && app.PhaseElapsed >= 0.75
                app.enterPhase(4, '低速调车', '下发牵引1级，列车低速启动');
            elseif app.DemoPhase == 4 && pos >= 210
                app.enterPhase(5, '通过道岔', '列车进入道岔区，保持调车限速');
            elseif app.DemoPhase == 5 && pos >= 335
                app.enterPhase(6, '目标股道', '列车进入B股道，开始制动停车');
            elseif app.DemoPhase == 6 && v <= 0.05 && pos >= 360
                app.enterPhase(7, '换线完成', '远程调车换线完成，列车停车');
            end

            switch app.DemoPhase
                case 0
                    app.Notch = 0;
                    app.ServiceBrake = true;
                    app.RouteState = '未建立';
                    app.SwitchState = '定位';
                    app.TrackState = 'A股道';
                    app.ModeText = '待机';
                case 1
                    app.Notch = 0;
                    app.ServiceBrake = true;
                    app.RouteState = '接管';
                    app.ModeText = '调车';
                case 2
                    app.Notch = 0;
                    app.ServiceBrake = true;
                    app.RouteState = '请求中';
                    app.SwitchState = '转换中';
                case 3
                    app.Notch = 0;
                    app.ServiceBrake = false;
                    app.RouteState = '已授权';
                    app.SwitchState = '反位锁闭';
                case 4
                    app.Notch = 2;
                    app.ServiceBrake = false;
                case 5
                    app.Notch = 1;
                    app.ServiceBrake = app.Speed > 28;
                    app.TrackState = '道岔区';
                case 6
                    app.Notch = -2;
                    app.ServiceBrake = true;
                    app.TrackState = 'B股道';
                case 7
                    app.Notch = 0;
                    app.ServiceBrake = true;
                    app.TrackState = 'B股道';
                    app.RouteState = '完成';
                    app.BrakeText = '制动';
            end
        end

        function enterPhase(app, phase, stateText, messageText)
            app.DemoPhase = phase;
            app.PhaseElapsed = 0;
            app.ScenarioState = stateText;
            if app.LastPhaseAnnounced ~= phase
                app.pushMessage(messageText);
                app.LastPhaseAnnounced = phase;
            end
        end

        function pushMessage(app, textValue)
            stamp = datestr(datetime('now'), 'HH:MM:SS');
            app.MessageLog = [{[stamp '  ' textValue]}; app.MessageLog(:)];
            if numel(app.MessageLog) > 8
                app.MessageLog = app.MessageLog(1:8);
            end
        end

        function refreshMessages(app)
            app.MessageArea.Value = app.MessageLog(1:min(4, numel(app.MessageLog)));
        end

        function out = toggleText(~, current, a, b)
            if strcmp(current, a)
                out = b;
            else
                out = a;
            end
        end

        function drawArrowIcon(~, ax, cx, cy, direction, color)
            if strcmp(direction, 'up')
                x = cx + [-14 -14 -24 0 24 14 14];
                y = cy + [-28 8 8 32 8 8 -28];
            else
                x = cx + [-14 -14 -24 0 24 14 14];
                y = cy + [28 -8 -8 -32 -8 -8 28];
            end
            patch(ax, x, y, color, 'EdgeColor', color, 'FaceAlpha', 0.98);
        end

        function drawAtoTrainIcon(app, ax, cx, cy)
            plot(ax, cx + [-12 2 13], cy + [-4 8 8], 'Color', app.C.white, 'LineWidth', 4);
            plot(ax, cx + [-8 4 18], cy + [-12 -12 -2], 'Color', app.C.white, 'LineWidth', 4);
            rectangle(ax, 'Position', [cx + 2 cy - 8 20 16], ...
                'FaceColor', 'none', 'EdgeColor', app.C.white, 'LineWidth', 3);
            rectangle(ax, 'Position', [cx + 5 cy - 4 5 5], 'FaceColor', app.C.white, 'EdgeColor', app.C.white);
            rectangle(ax, 'Position', [cx + 14 cy - 4 5 5], 'FaceColor', app.C.white, 'EdgeColor', app.C.white);
        end

        function drawDoorIcon(app, ax, cx, cy)
            rectangle(ax, 'Position', [cx - 18 cy - 17 36 34], ...
                'Curvature', 0.35, 'FaceColor', 'none', 'EdgeColor', app.C.white, 'LineWidth', 4);
            plot(ax, [cx - 6 cx - 6], [cy - 14 cy + 14], 'Color', app.C.white, 'LineWidth', 3);
            plot(ax, [cx + 6 cx + 6], [cy - 14 cy + 14], 'Color', app.C.white, 'LineWidth', 3);
        end

        function drawNetworkIcon(app, ax, cx, cy)
            plot(ax, [cx cx], [cy - 18 cy + 12], 'Color', app.C.white, 'LineWidth', 3);
            plot(ax, cx + [-10 0 10], cy + [-4 12 -4], 'Color', app.C.white, 'LineWidth', 3);
            theta = linspace(pi * 0.15, pi * 0.85, 30);
            plot(ax, cx + 18*cos(theta), cy - 2 + 18*sin(theta), 'Color', app.C.white, 'LineWidth', 2);
            plot(ax, cx + 27*cos(theta), cy - 2 + 27*sin(theta), 'Color', app.C.white, 'LineWidth', 2);
        end

        function drawMagnifierIcon(app, ax, cx, cy, symbolText)
            theta = linspace(0, 2*pi, 80);
            plot(ax, cx + 14*cos(theta), cy + 14*sin(theta), 'Color', app.C.white, 'LineWidth', 3);
            plot(ax, [cx + 10 cx + 24], [cy - 10 cy - 24], 'Color', app.C.white, 'LineWidth', 4);
            text(ax, cx, cy, symbolText, 'Color', app.C.white, 'FontSize', 20, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', 'FontName', 'Microsoft YaHei UI');
        end

        function h = addStatusLabel(app, pos, textValue, fontColor, bgColor, fontSize)
            if nargin < 6
                fontSize = 15;
            end
            h = uilabel(app.MainPanel);
            h.Position = pos;
            h.Text = sprintf(textValue);
            h.FontName = 'Microsoft YaHei UI';
            h.FontSize = fontSize;
            h.FontWeight = 'bold';
            h.FontColor = fontColor;
            h.BackgroundColor = bgColor;
            h.HorizontalAlignment = 'center';
            h.VerticalAlignment = 'center';
        end
    end

    methods (Access = public)
        function app = RemoteDMIApp
            startup(app);
            app.UIFigure.Visible = 'on';
        end

        function delete(app)
            if ~isempty(app.DemoTimer) && isvalid(app.DemoTimer)
                stop(app.DemoTimer);
                delete(app.DemoTimer);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end
