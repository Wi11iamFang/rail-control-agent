classdef ShuntScenarioState
    %SHUNTSCENARIOSTATE Business state machine for the candidate shunting demo.
    %   This is a display/validation state machine, not a safety-grade
    %   interlocking or ATP implementation.

    methods (Static)
        function names = names()
            names = { ...
                'FAULT_STOPPED', ...
                'REMOTE_TAKEOVER', ...
                'SHUNTING_MODE_READY', ...
                'ROUTE_REQUESTED', ...
                'INTERLOCK_CHECKING', ...
                'SWITCH_MOVING', ...
                'ROUTE_LOCKED', ...
                'SHUNT_SIGNAL_OPEN', ...
                'TRAIN_ENTERED_ROUTE', ...
                'OCCUPANCY_TRANSFER', ...
                'THROAT_PASSING', ...
                'ENTERED_TARGET_TRACK', ...
                'TARGET_BRAKING', ...
                'STOP_CONFIRMED', ...
                'ROUTE_RELEASED'};
        end

        function tf = canTransition(fromState, toState)
            names = ShuntScenarioState.names();
            idx = find(strcmp(names, fromState), 1);
            nextIdx = find(strcmp(names, toState), 1);
            tf = ~isempty(idx) && ~isempty(nextIdx) && nextIdx == idx + 1;
        end

        function [state, message] = transition(state, toState)
            if ~ShuntScenarioState.canTransition(state.scenarioState, toState)
                message = sprintf('非法状态迁移：%s -> %s', ...
                    state.scenarioState, toState);
                state.alarmState = 'state-transition-rejected';
                state.timestamp = datetime('now');
                return;
            end
            state.scenarioState = toState;
            state.timestamp = datetime('now');
            state.alarmState = 'none';
            message = sprintf('状态迁移：%s', toState);
        end

        function state = reset(state)
            state.scenarioState = 'FAULT_STOPPED';
            state.routeState = 'not-requested';
            state.mode = '待机';
            state.speedKmh = 0;
            state.positionM = 0;
            state.targetDistanceM = NaN;
            state.brakeState = 'applied';
            state.alarmState = 'none';
            state.timestamp = datetime('now');
        end
    end
end
