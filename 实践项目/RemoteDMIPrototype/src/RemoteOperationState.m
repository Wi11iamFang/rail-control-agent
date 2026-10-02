classdef RemoteOperationState
    %REMOTEOPERATIONSTATE Shared state consumed by ground and onboard views.
    %   This is a display/validation interface, not a safety-grade protocol.

    methods (Static)
        function state = initial(topology)
            route = topology.routes(1);
            state = struct();
            state.timestamp = datetime('now');
            state.scenarioState = 'FAULT_STOPPED';
            state.routeId = route.id;
            state.routeState = 'not-requested';
            state.controlAuthority = 'remote';
            state.mode = 'AM';
            state.speedKmh = 0;
            state.positionM = 0;
            state.accelerationMps2 = 0;
            state.targetDistanceM = NaN;
            state.currentTrack = route.sections{1};
            state.targetTrack = route.target;
            state.tractionNotch = 0;
            state.brakeNotch = 0;
            state.brakeState = 'applied';
            state.communicationState = 'normal';
            state.alarmState = 'none';
            state.switchPosition = RemoteOperationState.switchState(topology.switches);
            state.signalAspect = RemoteOperationState.signalState(topology.signals);
            state.trackOccupancy = RemoteOperationState.trackState(topology.sections, route.sections{1});
        end

        function out = switchState(switches)
            out = struct();
            for k = 1:numel(switches)
                out.(switches(k).id) = switches(k).position;
            end
        end

        function out = signalState(signals)
            out = struct();
            for k = 1:numel(signals)
                out.(signals(k).id) = signals(k).aspect;
            end
        end

        function out = trackState(sections, occupiedId)
            out = struct();
            for k = 1:numel(sections)
                out.(sections(k).id) = strcmp(sections(k).id, occupiedId);
            end
        end
    end
end
