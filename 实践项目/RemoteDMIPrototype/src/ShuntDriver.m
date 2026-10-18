classdef ShuntDriver < handle
    %SHUNTDRIVER Unified business driver for the shunting demo.
    %   Sole writer of the shared scenario state. All state transitions go
    %   through ShuntScenarioState; business actions follow the expert
    %   order (takeover -> route -> interlock -> lock -> signal -> run ->
    %   stop -> release). The three ends (ground / yard big screen / DMI)
    %   only read Context.State.
    %
    %   Display/validation prototype only, not a safety-grade controller.

    properties
        Context
        IsRunning = false
        RunTimer
        SpeedTargetKmh = 20
        MaxShuntKmh = 40
        StopPositionM = 420
        BrakeStartM = 404
        SimDtPerTick = 0.5
    end

    properties (Access = private)
        Notch = 0
        ServiceBrake = true
        LastTickMessage = ''
    end

    methods
        function obj = ShuntDriver(context)
            obj.Context = context;
            obj.RunTimer = timer( ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', 0.1, ...
                'TimerFcn', @(~, ~) obj.tick());
        end

        function delete(obj)
            if ~isempty(obj.RunTimer) && isvalid(obj.RunTimer)
                stop(obj.RunTimer);
                delete(obj.RunTimer);
            end
        end

        % --- Business commands (called by GroundControlApp buttons) ---

        function [state, message] = takeover(obj)
            state = obj.Context.State;
            [state, ~] = ShuntScenarioState.transition(state, 'REMOTE_TAKEOVER');
            if ~strcmp(state.scenarioState, 'REMOTE_TAKEOVER')
                state.alarmState = 'operation-rejected';
                obj.publish(state, '操作拒绝：当前状态不允许远程接管');
                return;
            end
            [state, ~] = ShuntScenarioState.transition(state, 'SHUNTING_MODE_READY');
            if ~strcmp(state.scenarioState, 'SHUNTING_MODE_READY')
                state.alarmState = 'operation-rejected';
                obj.publish(state, '操作拒绝：无法进入调车运行准备状态');
                return;
            end
            state.mode = '调车准备';
            state.routeState = 'takeover';
            state.alarmState = 'none';
            message = '远程接管完成，进入调车运行准备';
            obj.publish(state, message);
        end

        function [state, message] = requestRoute(obj)
            [state, message] = LocalInterlockingModel.requestRoute( ...
                obj.Context.State, obj.Context.Topology);
            obj.publish(state, message);
        end

        function [state, message] = checkRoute(obj)
            [state, message] = LocalInterlockingModel.checkRoute( ...
                obj.Context.State, obj.Context.Topology);
            obj.publish(state, message);
        end

        function [state, message] = lockRoute(obj)
            [state, message] = LocalInterlockingModel.lockRoute( ...
                obj.Context.State, obj.Context.Topology);
            obj.publish(state, message);
        end

        function [state, message] = openSignal(obj)
            [state, message] = LocalInterlockingModel.openSignal( ...
                obj.Context.State, obj.Context.Topology);
            obj.publish(state, message);
        end

        function [state, message] = startMoving(obj)
            state = obj.Context.State;
            if ~strcmp(state.scenarioState, 'SHUNT_SIGNAL_OPEN')
                state.alarmState = 'operation-rejected';
                message = '操作拒绝：调车信号尚未开放，不允许低速启动';
                obj.publish(state, message);
                return;
            end
            [state, message] = ShuntScenarioState.transition(state, 'TRAIN_ENTERED_ROUTE');
            state.mode = '调车';
            state.brakeState = 'released-ready';
            obj.Notch = 1;
            obj.ServiceBrake = false;
            obj.IsRunning = true;
            if strcmp(obj.RunTimer.Running, 'off')
                start(obj.RunTimer);
            end
            obj.publish(state, '调车信号已开放，车列沿锁闭进路低速运行');
        end

        function [state, message] = stopConfirmed(obj)
            state = obj.Context.State;
            if ~strcmp(state.scenarioState, 'TARGET_BRAKING')
                state.alarmState = 'operation-rejected';
                message = ['操作拒绝：当前状态 ' state.scenarioState ' 不允许停车确认'];
                obj.publish(state, message);
                return;
            end
            [state, message] = ShuntScenarioState.transition(state, 'STOP_CONFIRMED');
            state.brakeState = 'applied';
            state.routeState = 'stop-confirm-pending-release';
            obj.Notch = 0;
            obj.ServiceBrake = true;
            obj.publish(state, '停车确认完成，等待进路解锁');
        end

        function [state, message] = releaseRoute(obj)
            [state, message] = LocalInterlockingModel.releaseRoute( ...
                obj.Context.State, obj.Context.Topology);
            if strcmp(state.scenarioState, 'ROUTE_RELEASED')
                obj.IsRunning = false;
                if strcmp(obj.RunTimer.Running, 'on')
                    stop(obj.RunTimer);
                end
            end
            obj.publish(state, message);
        end

        % --- Run-time tick: plant step + occupancy + state progression ---

        function tick(obj)
            if ~obj.IsRunning
                return;
            end
            if isempty(obj.Context) || ~isvalid(obj.Context) || isempty(obj.Context.State)
                obj.IsRunning = false;
                return;
            end
            try
                state = obj.Context.State;
                plant = obj.Context.Plant;
                route = obj.Context.Topology.routes(1);

            % speed/limit control (bang-bang around target, 40 km/h cap)
            if state.positionM >= obj.BrakeStartM
                obj.Notch = 0;
                obj.ServiceBrake = true;
            elseif plant.VelocityMps * 3.6 < obj.SpeedTargetKmh - 1
                obj.Notch = 1;
                obj.ServiceBrake = false;
            elseif plant.VelocityMps * 3.6 > obj.SpeedTargetKmh + 1
                obj.Notch = 0;
                obj.ServiceBrake = true;
            end

            plantState = plant.step(obj.Notch, obj.ServiceBrake, false, obj.SimDtPerTick);
            state.speedKmh = plantState.speedKmh;
            state.positionM = plantState.positionM;
            state.accelerationMps2 = plantState.accelMps2;
            state.targetDistanceM = max(0, obj.StopPositionM - state.positionM);

            if state.speedKmh > obj.MaxShuntKmh
                state.alarmState = 'overspeed';
            elseif strcmp(state.alarmState, 'overspeed')
                state.alarmState = 'none';
            end

            % occupancy in route order
            if state.positionM < 210
                idx = 1;
            elseif state.positionM < 285
                idx = 2;
            elseif state.positionM < 335
                idx = 3;
            else
                idx = 4;
            end
            state = RemoteOperationState.updateTrackOccupancy(state, obj.Context.Topology, idx);
            state.currentTrack = route.sections{idx};

            % state progression along the route
            if state.positionM >= obj.BrakeStartM
                target = 'TARGET_BRAKING';
            elseif idx == 4
                target = 'ENTERED_TARGET_TRACK';
            elseif idx == 3
                target = 'THROAT_PASSING';
            elseif idx == 2
                target = 'OCCUPANCY_TRANSFER';
            else
                target = 'TRAIN_ENTERED_ROUTE';
            end
            if ~strcmp(state.scenarioState, target)
                [state, msg] = ShuntScenarioState.transition(state, target);
                if isempty(regexp(msg, '^非法状态迁移', 'once'))
                    obj.LastTickMessage = ['状态迁移：' msg];
                end
            end

            % stopped on target -> ask operator to confirm stop
            if plant.VelocityMps <= 0.05 && state.positionM >= obj.StopPositionM - 0.5 ...
                    && strcmp(state.scenarioState, 'TARGET_BRAKING')
                obj.LastTickMessage = '车列已停稳于目标区段，请操作员确认停车';
            end

            state.timestamp = datetime('now');
            obj.Context.publish(state, obj.LastTickMessage);
            catch err
                obj.IsRunning = false;
                if ~isempty(obj.RunTimer) && isvalid(obj.RunTimer)
                    stop(obj.RunTimer);
                end
                if ~isempty(obj.Context) && isvalid(obj.Context) && ...
                        ~isempty(obj.Context.State)
                    obj.Context.LastMessage = ['运行 tick 异常：' err.message];
                end
            end
        end
    end

    methods (Access = private)
        function publish(obj, state, message)
            obj.Context.publish(state, message);
        end
    end
end
