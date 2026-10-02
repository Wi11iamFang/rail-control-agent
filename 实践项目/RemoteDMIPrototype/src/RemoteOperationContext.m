classdef RemoteOperationContext < handle
    %REMOTEOPERATIONCONTEXT In-process shared context for ground/onboard apps.
    %   This is intentionally local MATLAB state; no TCP/UDP transport is used.

    properties
        Topology
        State
        Plant
        Timer
        ManualBusinessControl = false
        IsRunning = false
        LastMessage = ''
    end

    methods
        function obj = RemoteOperationContext(topology, state, plant)
            obj.Topology = topology;
            obj.State = state;
            obj.Plant = plant;
        end

        function publish(obj, state, message)
            obj.State = state;
            if nargin >= 3
                obj.LastMessage = message;
            end
        end

        function reset(obj)
            obj.State = RemoteOperationState.initial(obj.Topology);
            obj.Plant.reset(0);
            obj.ManualBusinessControl = false;
            obj.IsRunning = false;
            obj.LastMessage = '';
        end
    end
end
