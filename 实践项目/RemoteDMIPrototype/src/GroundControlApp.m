classdef GroundControlApp < handle
    %GROUNDCONTROLAPP Ground control panel for the local shunting demo.
    %   It shares one RemoteOperationContext with the onboard DMI and keeps
    %   the key onboard display elements needed by the ground operator.

    properties
        UIFigure
        Context
        Buttons
        LocalMapAxes
        SpeedLabel
        TargetLabel
        ModeLabel
        BrakeLabel
        SwitchLabel
        SignalLabel
        TrackLabel
        StatusLabel
        MessageArea
        RefreshTimer
    end

    methods
        function app = GroundControlApp(context)
            app.Context = context;
            app.createComponents();
            app.refresh();
            app.RefreshTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.25, 'TimerFcn', @(~, ~) app.onTick());
%             start(app.RefreshTimer);
        end

        function publishAndRefresh(app, message)
            app.Context.publish(app.Context.State, message);
            app.refresh();
        end

        function delete(app)
            if ~isempty(app.RefreshTimer) && isvalid(app.RefreshTimer)
                stop(app.RefreshTimer);
                delete(app.RefreshTimer);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = '地面远程调车控制端';
            app.UIFigure.Position = [80 90 1160 760];
            app.UIFigure.Resize = 'off';
            app.UIFigure.Color = [0.04 0.05 0.08];

            uilabel(app.UIFigure, 'Position', [24 706 900 34], ...
                'Text', '地面远程调车控制端（MATLAB 共享状态）', ...
                'FontName', 'Microsoft YaHei UI', 'FontSize', 18, ...
                'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);
            uilabel(app.UIFigure, 'Position', [24 680 620 22], ...
                'Text', '关键运行要素：速度 / 目标距离 / 道岔 / 信号 / 区段占用 / 事件流', ...
                'FontName', 'Microsoft YaHei UI', 'FontSize', 11, ...
                'FontColor', [0.55 0.65 0.72]);

            % Local line map
            app.LocalMapAxes = uiaxes(app.UIFigure);
            app.LocalMapAxes.Position = [24 150 700 512];
            app.prepareAxes(app.LocalMapAxes, [1 1423], [1 177]);
            app.LocalMapAxes.XLim = [1 1423];
            app.LocalMapAxes.YLim = [1 177];
            app.LocalMapAxes.YDir = 'reverse';
            app.LocalMapAxes.Visible = 'on';
            app.drawLocalMap();

            % Key operation info panel (right upper)
            panel = uipanel(app.UIFigure, 'Position', [748 430 390 260], ...
                'Title', '关键运行信息', 'FontName', 'Microsoft YaHei UI', ...
                'FontWeight', 'bold', 'ForegroundColor', [0.92 0.96 1.00], ...
                'BackgroundColor', [0.05 0.06 0.10], ...
                'ForegroundColor', [0.75 0.82 0.90]);
            app.SpeedLabel = uilabel(panel, 'Position', [16 170 358 70], ...
                'Text', '速度  0 km/h', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 26, 'FontWeight', 'bold', ...
                'FontColor', [0.92 0.96 1.00], ...
                'HorizontalAlignment', 'center');
            app.TargetLabel = uilabel(panel, 'Position', [16 116 358 40], ...
                'Text', '目标距离  420 m', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 18, 'FontWeight', 'bold', ...
                'FontColor', [0.92 0.96 1.00], ...
                'HorizontalAlignment', 'center');
            app.ModeLabel = uilabel(panel, 'Position', [16 74 358 32], ...
                'Text', '模式：待机', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'FontColor', [0.92 0.96 1.00], ...
                'HorizontalAlignment', 'center');
            app.BrakeLabel = uilabel(panel, 'Position', [16 36 358 32], ...
                'Text', '制动：已施加', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'FontColor', [0.92 0.96 1.00], ...
                'HorizontalAlignment', 'center');

            % Device status three elements (right middle)
            devPanel = uipanel(app.UIFigure, 'Position', [748 258 390 160], ...
                'Title', '设备状态（地面/车载一致）', ...
                'FontName', 'Microsoft YaHei UI', 'FontWeight', 'bold', ...
                'BackgroundColor', [0.05 0.06 0.10], ...
                'ForegroundColor', [0.75 0.82 0.90]);
            app.SwitchLabel = uilabel(devPanel, 'Position', [16 90 358 36], ...
                'Text', '道岔：待操作', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);
            app.SignalLabel = uilabel(devPanel, 'Position', [16 52 358 36], ...
                'Text', '信号：关闭', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);
            app.TrackLabel = uilabel(devPanel, 'Position', [16 14 358 36], ...
                'Text', '区段：C21G1 空闲', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);

            % Business action buttons (right bottom)
            labels = {'远程接管','办理进路','联锁检查','锁闭进路', ...
                '开放信号','低速启动','停车确认','进路解锁'};
            app.Buttons = gobjects(1, numel(labels));
            for k = 1:numel(labels)
                row = floor((k - 1) / 2);
                col = mod(k - 1, 2);
                btn = uibutton(app.UIFigure, 'push');
                btn.Position = [748 + col * 196, 150 + (1 - row) * 50, 180, 40];
                btn.Text = labels{k};
                btn.FontName = 'Microsoft YaHei UI';
                btn.FontSize = 13;
                btn.FontWeight = 'bold';
                btn.ButtonPushedFcn = @(~, ~) app.onAction(k);
                app.Buttons(k) = btn;
            end

            % Event flow
            app.MessageArea = uitextarea(app.UIFigure, 'Position', [24 32 700 100], ...
                'Editable', 'off', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 12, 'BackgroundColor', [0.02 0.025 0.03], ...
                'FontColor', [0.92 0.96 1.00]);
            app.StatusLabel = uilabel(app.UIFigure, 'Position', [748 44 390 84], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 13, 'FontWeight', 'bold', ...
                'FontColor', [0.92 0.96 1.00], 'WordWrap', 'on', ...
                'HorizontalAlignment', 'left');

            app.UIFigure.Visible = 'on';
        end

        function prepareAxes(app, ax, xlimv, ylimv)
            ax.Color = [0.02 0.03 0.06];
            ax.XColor = 'none';
            ax.YColor = 'none';
            ax.Toolbar.Visible = 'off';
            ax.Interactions = [];
            ax.XLim = xlimv;
            ax.YLim = ylimv;
            ax.NextPlot = 'add';
            axis(ax, 'manual');
        end

        function drawLocalMap(app)
            ax = app.LocalMapAxes;
            cla(ax);
            imagePath = app.Context.Topology.imagePath;
            if exist(imagePath, 'file') ~= 2
                text(ax, 20, 90, '局部线路图未找到', 'Color', [1 0.2 0.2], ...
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

            g = app.Context.Topology.displayGeometry;
            route = app.Context.Topology.routes(1);
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
                    'Color', [1 0.94 0.18], 'LineWidth', 2.2);
                pos = app.Context.State.positionM;
                cum = [0; sqrt(sum(diff(routePoints, 1, 1).^2, 2))];
                cum = cumsum(cum);
                q = min(max(pos / 420 * cum(end), 0), cum(end));
                x = interp1(cum, routePoints(:, 1), q, 'linear');
                y = interp1(cum, routePoints(:, 2), q, 'linear');
                scatter(ax, x, y, 52, [1 0.16 0.12], 'filled', ...
                    'MarkerEdgeColor', [0.95 0.95 0.95], 'LineWidth', 1.2);
            end
            text(ax, 8, 14, '局部图：PNG底图 / 候选进路叠加', ...
                'Color', [0.92 0.96 1.00], 'FontSize', 9, ...
                'BackgroundColor', [0.02 0.03 0.09], ...
                'Margin', 2, 'FontName', 'Microsoft YaHei UI');
        end

        function onAction(app, index)
            state = app.Context.State;
            topology = app.Context.Topology;
            message = '';
            switch index
                case 1
                    if strcmp(state.scenarioState, 'FAULT_STOPPED')
                        state.scenarioState = 'SHUNTING_MODE_READY';
                        state.mode = '调车准备';
                        state.routeState = 'takeover';
                        message = '远程接管完成，进入调车运行准备';
                    else
                        message = ['操作拒绝：当前状态 ' state.scenarioState];
                    end
                case 2
                    [state, message] = LocalInterlockingModel.requestRoute(state, topology);
                case 3
                    [state, message] = LocalInterlockingModel.checkRoute(state, topology);
                case 4
                    [state, message] = LocalInterlockingModel.lockRoute(state, topology);
                case 5
                    [state, message] = LocalInterlockingModel.openSignal(state, topology);
                case 6
                    if strcmp(state.scenarioState, 'SHUNT_SIGNAL_OPEN')
                        app.Context.ManualBusinessControl = true;
                        state.mode = '调车';
                        state.brakeState = 'released-ready';
                        message = '调车信号已开放，允许低速启动';
                        if ~app.Context.IsRunning
                            start(app.RefreshTimer);
                            app.Context.IsRunning = true;
                        end
                    else
                        message = '操作拒绝：调车信号尚未开放';
                        state.alarmState = 'operation-rejected';
                    end
                case 7
                    if strcmp(state.scenarioState, 'SHUNT_SIGNAL_OPEN')
                        state.scenarioState = 'STOP_CONFIRMED';
                        state.routeState = 'stop-confirm-pending-release';
                        state.brakeState = 'applied';
                        message = '停车确认完成，等待进路解锁';
                    else
                        message = ['操作拒绝：当前状态 ' state.scenarioState];
                        state.alarmState = 'operation-rejected';
                    end
                case 8
                    [state, message] = LocalInterlockingModel.releaseRoute(state, topology);
            end
            state.timestamp = datetime('now');
            app.Context.publish(state, message);
            app.refresh();
        end

        function onTick(app)
            if ~app.Context.IsRunning
                return;
            end
            state = app.Context.State;
            dt = 0.25;
            plantState = app.Context.Plant.step(1, false, false, dt);
            state.speedKmh = plantState.speedKmh;
            state.positionM = plantState.positionM;
            state.accelerationMps2 = plantState.accelerationMps2;
            state.targetDistanceM = max(0, 420 - plantState.positionM);
            route = app.Context.Topology.routes(1);
            if plantState.positionM < 210
                index = 1;
            elseif plantState.positionM < 285
                index = 2;
            elseif plantState.positionM < 335
                index = 3;
            else
                index = 4;
            end
            state = RemoteOperationState.updateTrackOccupancy(state, app.Context.Topology, index);
            state.scenarioState = 'OCCUPANCY_TRANSFER';
            state.currentTrack = route.sections{index};
            state.timestamp = datetime('now');
            app.Context.publish(state, '地面端驱动列车沿候选进路低速运行');
            app.refresh();
            app.drawLocalMap();
        end

        function refresh(app)
            s = app.Context.State;
            app.SpeedLabel.Text = sprintf('速度  %.1f km/h', s.speedKmh);
            app.TargetLabel.Text = sprintf('目标距离  %.0f m', max(0, s.targetDistanceM));
            app.ModeLabel.Text = ['模式：' char(s.mode)];
            app.BrakeLabel.Text = ['制动：' char(s.brakeState)];
            if isfield(s.switchPosition, 'W_LOCAL_1')
                app.SwitchLabel.Text = ['道岔 W_LOCAL_1：' char(s.switchPosition.W_LOCAL_1)];
            end
            if isfield(s.signalAspect, 'XC21')
                app.SignalLabel.Text = ['信号 XC21：' char(s.signalAspect.XC21)];
            end
            if isfield(s.trackOccupancy, 'C21G1')
                occ = s.trackOccupancy.C21G1;
                if occ
                    app.TrackLabel.Text = ['区段：C21G1 占用 / 当前 ' char(s.currentTrack)];
                else
                    app.TrackLabel.Text = ['区段：C21G1 空闲 / 当前 ' char(s.currentTrack)];
                end
            end
            app.StatusLabel.Text = sprintf('状态：%s    进路：%s', ...
                s.scenarioState, s.routeState);
            if isempty(app.Context.LastMessage)
                app.MessageArea.Value = {'等待地面端操作'};
            else
                app.MessageArea.Value = {app.Context.LastMessage};
            end
        end
    end
end