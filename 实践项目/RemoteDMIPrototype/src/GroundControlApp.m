classdef GroundControlApp < handle
    %GROUNDCONTROLAPP Minimal ground control panel for the local demo.
    %   It shares one RemoteOperationContext with the onboard DMI.

    properties
        UIFigure
        Context
        Buttons
        StatusLabel
        MessageArea
        Timer
    end

    methods
        function app = GroundControlApp(context)
            app.Context = context;
            app.createComponents();
            app.refresh();
            app.Timer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.25, 'TimerFcn', @(~, ~) app.onTick());
        end

        function delete(app)
            if ~isempty(app.Timer) && isvalid(app.Timer)
                stop(app.Timer);
                delete(app.Timer);
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
            app.UIFigure.Position = [60 560 520 430];
            app.UIFigure.Resize = 'off';
            app.UIFigure.Color = [0.04 0.05 0.08];

            uilabel(app.UIFigure, 'Position', [24 380 460 30], ...
                'Text', '地面远程调车控制端（MATLAB共享状态）', ...
                'FontName', 'Microsoft YaHei UI', 'FontSize', 16, ...
                'FontWeight', 'bold', 'FontColor', [0.92 0.96 1.00]);

            labels = {'远程接管','办理进路','联锁检查','锁闭进路', ...
                '开放信号','低速启动','停车确认','进路解锁'};
            app.Buttons = gobjects(1, numel(labels));
            for k = 1:numel(labels)
                row = floor((k - 1) / 2);
                col = mod(k - 1, 2);
                btn = uibutton(app.UIFigure, 'push');
                btn.Position = [24 + col * 238, 285 - row * 54, 215, 42];
                btn.Text = labels{k};
                btn.FontName = 'Microsoft YaHei UI';
                btn.FontSize = 13;
                btn.FontWeight = 'bold';
                btn.ButtonPushedFcn = @(~, ~) app.onAction(k);
                app.Buttons(k) = btn;
            end

            app.StatusLabel = uilabel(app.UIFigure, 'Position', [24 42 470 45], ...
                'Text', '', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 12, 'FontColor', [0.92 0.96 1.00]);
            app.MessageArea = uitextarea(app.UIFigure, 'Position', [24 96 470 70], ...
                'Editable', 'off', 'FontName', 'Microsoft YaHei UI', ...
                'FontSize', 12, 'BackgroundColor', [0.02 0.025 0.03], ...
                'FontColor', [0.92 0.96 1.00]);
            app.UIFigure.Visible = 'on';
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
                            start(app.Timer);
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
        end

        function refresh(app)
            s = app.Context.State;
            app.StatusLabel.Text = sprintf('状态：%s    进路：%s    当前区段：%s', ...
                s.scenarioState, s.routeState, s.currentTrack);
            if isempty(app.Context.LastMessage)
                app.MessageArea.Value = {'等待地面端操作'};
            else
                app.MessageArea.Value = {app.Context.LastMessage};
            end
        end
    end
end
