classdef RemoteDMIApp < matlab.apps.AppBase
    % RemoteDMIApp
    % 车载 DMI 主界面（纯显示端）：只消费共享状态，不写状态、不操作业务。
    % 右侧业务按钮已移除，业务动作统一由地面端（GroundControlApp + ShuntDriver）执行。

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
        RefreshTimer
        Blink = false
        Deleted = false
        Speed = 0
        PermittedSpeed = 40
        TrainX = 1.0
        TargetDistance = 420
        KmMeter = 54.751
        ModeText = '待机'
        StationName = '宜昌北动车所'
        TrainNo = 'D2'
        DoorHint = '双侧'
        BrakeText = '制动'
        ControlText = '机控'
        Plant
        TargetPositionM = 420
        RouteState = '未建立'
        SwitchState = '定位'
        TrackState = 'C21G1'
        ScenarioState = '故障停车'
        Topology
        SharedState
        Context
        Renderer
    end

    methods (Access = private)
        function startup(app)
            app.Topology = app.Context.Topology;
            app.SharedState = app.Context.State;
            app.Plant = app.Context.Plant;
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

            app.resetScenario();

            app.createComponents();
            app.Renderer = YardViewRenderer(app.LocalMapAxes, app.Topology);
            app.refreshAll();

            app.RefreshTimer = timer( ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', 0.25, ...
                'TimerFcn', @(~, ~) app.refreshAll());
            start(app.RefreshTimer);
        end

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = '车载 DMI（纯显示，共享状态驱动）';
            app.UIFigure.Color = app.C.bg;
            app.UIFigure.Position = [70 40 1280 900];
            app.UIFigure.Resize = 'off';

            app.MainPanel = uipanel(app.UIFigure);
            app.MainPanel.BorderType = 'line';
            app.MainPanel.BackgroundColor = app.C.bg;
            app.MainPanel.Position = [28 28 1224 844];

            app.SpeedAxes = uiaxes(app.MainPanel);
            app.SpeedAxes.Position = [54 408 430 390];
            app.prepareAxes(app.SpeedAxes, [-1.2 1.2], [-1.1 1.15]);

            app.PlanAxes = uiaxes(app.MainPanel);
            app.PlanAxes.Position = [520 408 440 390];
            app.prepareAxes(app.PlanAxes, [0 16], [0 320]);

            app.DistanceAxes = uiaxes(app.MainPanel);
            app.DistanceAxes.Position = [54 170 140 210];
            app.prepareAxes(app.DistanceAxes, [0 1], [0 1000]);

            app.StatusAxes = uiaxes(app.MainPanel);
            app.StatusAxes.Position = [520 155 440 220];
            app.prepareAxes(app.StatusAxes, [0 440], [0 220]);

            app.LocalMapAxes = uiaxes(app.MainPanel);
            app.LocalMapAxes.Position = [180 28 780 97];

            app.MessageArea = uitextarea(app.MainPanel);
            app.MessageArea.Position = [205 155 290 190];
            app.MessageArea.BackgroundColor = [0.02 0.025 0.025];
            app.MessageArea.FontColor = app.C.white;
            app.MessageArea.FontName = 'Microsoft YaHei UI';
            app.MessageArea.FontSize = 15;
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
            if app.Deleted || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                app.stopRefreshTimer();
                return;
            end
            try
                app.refreshFromContext();
                app.drawSpeedometer();
                app.drawPlanArea();
                if ~isempty(app.Renderer)
                    app.Renderer.update(app.Context.State);
                end
                app.drawDistanceAndStatus();
                app.drawBottomStatus();
                app.refreshMessages();
                drawnow limitrate;
            catch
                app.stopRefreshTimer();
            end
        end

        function stopRefreshTimer(app)
            if ~isempty(app.RefreshTimer) && isvalid(app.RefreshTimer)
                stop(app.RefreshTimer);
                delete(app.RefreshTimer);
            end
            app.RefreshTimer = [];
        end

        function refreshFromContext(app)
            s = app.Context.State;
            app.SharedState = s;
            app.Speed = s.speedKmh;
            app.TargetDistance = max(0, s.targetDistanceM);
            app.ModeText = s.mode;
            app.BrakeText = s.brakeState;
            app.RouteState = s.routeState;
            app.TrackState = s.currentTrack;
            app.ScenarioState = s.scenarioState;
            app.KmMeter = 54.751 + s.positionM / 1000;
            app.TrainX = min(15.2, 1.0 + s.positionM / max(app.TargetPositionM, 1) * 13.4);
            if isfield(s.switchPosition, 'W_LOCAL_1')
                app.SwitchState = s.switchPosition.W_LOCAL_1;
            end
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
            if any(strcmp(app.TrackState, {'THROAT_LOCAL_1', 'THROAT_LOCAL_2'}))
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
            text(ax, 0.8, 274, ['进路：' app.RouteState '  道岔W1：' app.SwitchState], ...
                'Color', app.C.white, 'FontSize', 11, 'FontName', 'Microsoft YaHei UI');
            text(ax, 10.3, 70, app.TrackState, 'Color', app.C.white, 'FontSize', 12, ...
                'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI');
        end

        function drawDistanceAndStatus(app)
            ax = app.DistanceAxes;
            cla(ax);
            rectangle(ax, 'Position', [0.12 0 0.76 1000], ...
                'FaceColor', [0.10 0.10 0.10], 'EdgeColor', app.C.dim);
            fill(ax, [0.12 0.88 0.88 0.12], [0 0 app.TargetDistance app.TargetDistance], ...
                [0.86 0.60 0.32], 'EdgeColor', 'none', 'FaceAlpha', 0.88);
            text(ax, 0.50, 930, ['目标 ' app.TrackState], 'Color', app.C.white, 'FontSize', 13, ...
                'HorizontalAlignment', 'center', 'FontName', 'Microsoft YaHei UI');
            text(ax, 0.50, 770, sprintf('%d m', round(app.TargetDistance)), ...
                'Color', app.C.white, 'FontSize', 19, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'FontName', 'Microsoft YaHei UI');
            text(ax, 0.50, 570, '目标距离', 'Color', app.C.white, 'FontSize', 14, ...
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

        function refreshMessages(app)
            if ~isempty(app.Context) && ~isempty(app.Context.LastMessage)
                app.MessageArea.Value = {app.Context.LastMessage};
            else
                app.MessageArea.Value = {'等待地面端操作'};
            end
        end

        function resetScenario(app)
            app.TargetPositionM = 420;
            app.PermittedSpeed = 40;
            app.Speed = 0;
            app.TargetDistance = app.TargetPositionM;
            app.KmMeter = 54.751;
            app.ModeText = '待机';
            app.BrakeText = '制动';
            app.ControlText = '机控';
            app.RouteState = 'not-requested';
            app.SwitchState = 'unknown';
            app.TrackState = 'C21G1';
            app.ScenarioState = 'FAULT_STOPPED';
            if ~isempty(app.Plant)
                app.Plant.reset(0);
            end
        end
    end

    methods (Access = public)
        function app = RemoteDMIApp(context)
            app.Context = context;
            startup(app);
            app.UIFigure.Visible = 'on';
        end

        function delete(app)
            app.Deleted = true;
            app.stopRefreshTimer();
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end
