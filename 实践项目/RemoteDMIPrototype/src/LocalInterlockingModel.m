classdef LocalInterlockingModel
    %LOCALINTERLOCKINGMODEL Minimal candidate-route interlocking actions.
    %   This model is for demonstration validation only, not a safety-grade
    %   interlocking implementation or a verified route table.

    methods (Static)
        function [state, message] = requestRoute(state, topology)
            if ~strcmp(state.scenarioState, 'SHUNTING_MODE_READY')
                [state, message] = LocalInterlockingModel.reject(state, ...
                    '须先完成远程接管并建立调车运行准备状态');
                return;
            end
            route = topology.routes(1);
            state.routeId = route.id;
            state.routeState = 'requested';
            state.scenarioState = 'ROUTE_REQUESTED';
            state.timestamp = datetime('now');
            message = '已请求候选调车进路，等待联锁检查';
        end

        function [state, message] = checkRoute(state, topology)
            if ~strcmp(state.scenarioState, 'ROUTE_REQUESTED')
                [state, message] = LocalInterlockingModel.reject(state, ...
                    '当前状态不允许执行联锁检查');
                return;
            end
            route = topology.routes(1);
            for k = 1:numel(route.sections)
                if ~isfield(state.trackOccupancy, route.sections{k})
                    [state, message] = LocalInterlockingModel.reject(state, ...
                        '候选进路包含未定义区段');
                    return;
                end
            end
            state.routeState = 'interlock-checked';
            state.scenarioState = 'INTERLOCK_CHECKING';
            state.timestamp = datetime('now');
            message = '候选进路基础条件检查通过，等待道岔转换';
        end

        function [state, message] = lockRoute(state, topology)
            if ~strcmp(state.scenarioState, 'INTERLOCK_CHECKING')
                [state, message] = LocalInterlockingModel.reject(state, ...
                    '当前状态不允许锁闭进路');
                return;
            end
            route = topology.routes(1);
            for k = 1:numel(route.switches)
                id = route.switches{k};
                state.switchPosition.(id) = 'locked-candidate';
            end
            state.routeState = 'locked-candidate';
            state.scenarioState = 'ROUTE_LOCKED';
            state.timestamp = datetime('now');
            message = '候选进路已锁闭；道岔要求位置仍待正式资料确认';
        end

        function [state, message] = openSignal(state, topology)
            if ~strcmp(state.scenarioState, 'ROUTE_LOCKED')
                [state, message] = LocalInterlockingModel.reject(state, ...
                    '须先完成道岔到位和进路锁闭');
                return;
            end
            signalId = topology.routes(1).startSignal;
            state.signalAspect.(signalId) = 'shunting-open';
            state.routeState = 'signal-open';
            state.scenarioState = 'SHUNT_SIGNAL_OPEN';
            state.brakeState = 'released-ready';
            state.timestamp = datetime('now');
            message = '调车信号开放，允许车列低速运行';
        end

        function [state, message] = releaseRoute(state, topology)
            if ~strcmp(state.scenarioState, 'STOP_CONFIRMED')
                [state, message] = LocalInterlockingModel.reject(state, ...
                    '须先完成停稳确认');
                return;
            end
            signalId = topology.routes(1).startSignal;
            state.signalAspect.(signalId) = 'closed';
            route = topology.routes(1);
            for k = 1:numel(route.switches)
                state.switchPosition.(route.switches{k}) = 'unlocked-candidate';
            end
            state.routeState = 'released-candidate';
            state.scenarioState = 'ROUTE_RELEASED';
            state.timestamp = datetime('now');
            message = '候选进路已解锁；解锁方式仍待正式资料确认';
        end
    end

    methods (Static, Access = private)
        function [state, message] = reject(state, message)
            state.alarmState = 'operation-rejected';
            state.timestamp = datetime('now');
        end
    end
end
