classdef YardViewApp < handle
    %YARDVIEWAPP Independent shunting yard big-screen window.
    %   The third end of the demo: renders the candidate route as vector
    %   graphics from the shared state. Display only; never writes state.

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
    end

    methods
        function app = YardViewApp(context)
            app.Context = context;
            app.C.bg = [0.03 0.04 0.07];
            app.C.white = [0.92 0.96 1.00];
            app.C.dim = [0.46 0.55 0.62];
            app.createComponents();
            app.Renderer = YardViewRenderer(app.YardAxes, app.Context.Topology);
            app.refresh();
            app.RefreshTimer = timer( ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', 0.08, ...
                'TimerFcn', @(~, ~) app.onTick());
            start(app.RefreshTimer);
        end

        function onTick(app)
            if isempty(app.Context) || isempty(app.Context.State)
                return;
            end
            app.Renderer.update(app.Context.State);
            app.refreshLabels();
        end

        function refresh(app)
            app.Renderer.update(app.Context.State);
            app.refreshLabels();
            app.UIFigure.Visible = 'on';
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
            app.UIFigure.Name = '转线演示大屏（矢量站场）';
            app.UIFigure.Position = [1200 200 1280 720];
            app.UIFigure.Resize = 'off';
            app.UIFigure.Color = app.C.bg;

            title = uilabel(app.UIFigure, 'Position', [24 660 1232 36], ...
                'Text', '远程调车转线演示大屏（C21G1 → 咽喉区 → D20 方向候选进路）', ...
                'FontName', 'Microsoft YaHei UI', 'FontSize', 20, ...
                'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);

            app.YardAxes = uiaxes(app.UIFigure);
            app.YardAxes.Position = [40 140 1200 500];

            app.StateLabel = uilabel(app.UIFigure, 'Position', [40 96 700 28], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', 'FontSize', 15, ...
                'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);
            app.RouteLabel = uilabel(app.UIFigure, 'Position', [40 66 700 28], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', 'FontSize', 13, ...
                'FontColor', [0.75 0.82 0.90]);
            app.SpeedLabel = uilabel(app.UIFigure, 'Position', [760 66 460 28], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', 'FontSize', 13, ...
                'FontColor', [0.75 0.82 0.90]);
        end

        function refreshLabels(app)
            s = app.Context.State;
            app.StateLabel.Text = sprintf('业务状态：%s    区段占用：%s', ...
                char(s.scenarioState), char(s.currentTrack));
            app.RouteLabel.Text = sprintf('进路：%s    道岔：%s / %s    信号 XC21：%s', ...
                char(s.routeState), ...
                char(s.switchPosition.W_LOCAL_1), ...
                char(s.switchPosition.W_LOCAL_2), ...
                char(s.signalAspect.XC21));
            app.SpeedLabel.Text = sprintf('速度 %.1f km/h    位置 %.0f m', ...
                s.speedKmh, s.positionM);
        end
    end
end
