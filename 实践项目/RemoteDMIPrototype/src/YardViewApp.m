classdef YardViewApp < handle
    %YARDVIEWAPP Independent shunting yard big-screen window (banner layout).
    %   The third end of the demo: renders the candidate route as vector
    %   graphics from the shared state in a wide thin banner, matching the
    %   reference line-plan look. Display only; never writes state.

    properties
        UIFigure
        YardAxes
        Context
        Renderer
        RefreshTimer
        StateLabel
        RouteLabel
        SpeedLabel
    end

    properties (Access = private)
        C = struct()
        Deleted = false
    end

    methods
        function app = YardViewApp(context)
            app.Context = context;
            app.C.bg = [0.02 0.03 0.06];
            app.C.white = [0.92 0.96 1.00];
            app.C.dim = [0.50 0.58 0.66];
            app.createComponents();
            app.Renderer = YardViewRenderer(app.YardAxes, app.Context.Topology);
            app.Renderer.SignalBlink = true;   % enable blink only on the big screen
            app.refresh();
            app.RefreshTimer = timer( ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', 0.08, ...
                'TimerFcn', @(~, ~) app.onTick());
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
            try
                app.Renderer.update(app.Context.State);
            catch
                app.stopRefreshTimer();
                return;
            end
            app.refreshLabels();
        end

        function refresh(app)
            app.Renderer.update(app.Context.State);
            app.refreshLabels();
            app.UIFigure.Visible = 'on';
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
            % Wide thin banner window: title + 8:1 yard view + info bar.
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = '转线演示大屏（矢量站场横幅）';
            app.UIFigure.Position = [1200 120 1440 420];
            app.UIFigure.Resize = 'off';
            app.UIFigure.Color = app.C.bg;

            title = uilabel(app.UIFigure, 'Position', [24 378 1400 32], ...
                'Text', '远程调车转线演示大屏（C21G1 → 咽喉区 → D20 方向候选进路）', ...
                'FontName', 'Microsoft YaHei UI', 'FontSize', 20, ...
                'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);

            % 8:1 yard view matching the source data aspect (1423 x 177)
            app.YardAxes = uiaxes(app.UIFigure);
            app.YardAxes.Position = [40 128 1360 170];

            app.StateLabel = uilabel(app.UIFigure, 'Position', [40 88 1060 26], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', 'FontSize', 15, ...
                'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);
            app.RouteLabel = uilabel(app.UIFigure, 'Position', [40 58 1060 26], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', 'FontSize', 13, ...
                'FontColor', [0.80 0.86 0.92]);
            app.SpeedLabel = uilabel(app.UIFigure, 'Position', [1120 58 300 26], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', 'FontSize', 13, ...
                'FontColor', [0.80 0.86 0.92]);
        end

        function refreshLabels(app)
            s = app.Context.State;
            app.StateLabel.Text = sprintf('业务状态：%s    区段占用：%s → 目标 %s', ...
                char(s.scenarioState), char(s.currentTrack), char(s.targetTrack));
            app.RouteLabel.Text = sprintf('进路：%s    道岔 W1：%s / W2：%s    信号 XC21：%s', ...
                char(s.routeState), ...
                char(s.switchPosition.W_LOCAL_1), ...
                char(s.switchPosition.W_LOCAL_2), ...
                char(s.signalAspect.XC21));
            app.SpeedLabel.Text = sprintf('速度 %.1f km/h    位置 %.0f m', ...
                s.speedKmh, s.positionM);
        end
    end
end