classdef GroundControlApp < handle
    %GROUNDCONTROLAPP Ground control panel for the local shunting demo.
    %   Shares one RemoteOperationContext with the onboard DMI and the yard
    %   big screen. All business buttons call ShuntDriver; this app only
    %   sends commands and renders the shared state (no direct writes).

    properties
        UIFigure
        Context
        Buttons
        LocalMapAxes
        Renderer
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

    properties (Access = private)
        Deleted = false
    end

    methods
        function app = GroundControlApp(context)
            app.Context = context;
            app.createComponents();
            app.Renderer = YardViewRenderer(app.LocalMapAxes, context.Topology);
            app.refresh();
            app.RefreshTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.25, 'TimerFcn', @(~, ~) app.onTick());
            start(app.RefreshTimer);
        end

        function onTick(app)
            % Guard against zombies after `close all force`.
            if app.Deleted || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                app.stopRefreshTimer();
                return;
            end
            if isempty(app.Context) || isempty(app.Context.State)
                return;
            end
            if ~isempty(app.Renderer)
                try
                    app.Renderer.update(app.Context.State);
                catch
                    app.stopRefreshTimer();
                    return;
                end
            end
            app.refresh();
        end

        function delete(app)
            app.Deleted = true;
            app.stopRefreshTimer();
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        function stopRefreshTimer(app)
            if ~isempty(app.RefreshTimer) && isvalid(app.RefreshTimer)
                stop(app.RefreshTimer);
                delete(app.RefreshTimer);
            end
            app.RefreshTimer = [];
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

            % Local vector yard view (no PNG base image)
            app.LocalMapAxes = uiaxes(app.UIFigure);
            app.LocalMapAxes.Position = [24 150 700 512];

            % Key operation info panel (right upper)
            panel = uipanel(app.UIFigure, 'Position', [748 430 390 260], ...
                'Title', '关键运行信息', 'FontName', 'Microsoft YaHei UI', ...
                'FontWeight', 'bold', 'ForegroundColor', [0.92 0.96 1.00], ...
                'BackgroundColor', [0.05 0.06 0.10]);
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
                'BackgroundColor', [0.05 0.06 0.10]);
            app.SwitchLabel = uilabel(devPanel, 'Position', [16 90 358 36], ...
                'Text', '道岔：待操作', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);
            app.SignalLabel = uilabel(devPanel, 'Position', [16 52 358 36], ...
                'Text', '信号：关闭', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);
            app.TrackLabel = uilabel(devPanel, 'Position', [16 14 358 36], ...
                'Text', '区段：C21G1 空闲', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);

            % Business action buttons (right bottom) -> ShuntDriver
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
            app.StatusLabel = uilabel(app.UIFigure, 'Position', [748 4 390 44], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [0.92 0.96 1.00], 'WordWrap', 'on', ...
                'HorizontalAlignment', 'left');

            app.UIFigure.Visible = 'on';
        end

        function onAction(app, index)
            driver = app.Context.Driver;
            state = [];
            message = '';
            switch index
                case 1
                    [state, message] = driver.takeover();
                case 2
                    [state, message] = driver.requestRoute();
                case 3
                    [state, message] = driver.checkRoute();
                case 4
                    [state, message] = driver.lockRoute();
                case 5
                    [state, message] = driver.openSignal();
                case 6
                    [state, message] = driver.startMoving();
                case 7
                    [state, message] = driver.stopConfirmed();
                case 8
                    [state, message] = driver.releaseRoute();
            end
            if ~isempty(state)
                app.Context.State = state;
            end
            app.refresh();
            if ~isempty(app.Renderer)
                app.Renderer.update(app.Context.State);
            end
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
