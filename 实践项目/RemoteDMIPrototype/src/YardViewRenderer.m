classdef YardViewRenderer < handle
    %YARDVIEWRENDERER Vector yard renderer shared by the three ends.
    %   Draws the candidate local topology as vector graphics objects once,
    %   then updates only their properties from the shared state, so the
    %   shunting scene animates without redrawing a PNG base image.
    %
    %   Display only: never writes to the shared state.

    properties
        Ax            % uiaxes
        Topology      % RouteTopology struct
        RouteLengthM = 420  % demo mapping: positionM -> full route length
    end

    properties (Access = private)
        SectionLines     % struct: id -> line handle
        SectionLabels    % struct: id -> text handle
        SwitchNormal     % struct: id -> line handle (direct branch)
        SwitchReverse    % struct: id -> line handle (route branch)
        SwitchPivots     % struct: id -> [x y]
        SwitchKeys       % cell of switch ids
        SignalHeads      % struct: id -> patch handle (signal lamp)
        SignalKeys       % cell of signal ids
        RoutePoly        % [N x 2] polyline of the candidate route
        RouteCum         % cumulative pixel length
        RouteLine        % line handle for route highlight
        TrainPatch       % patch handle for the train
        TrainText        % text handle "车列"
        IsBuilt = false
    end

    methods
        function obj = YardViewRenderer(ax, topology)
            obj.Ax = ax;
            obj.Topology = topology;
            obj.buildStatic();
            obj.buildRouteGeometry();
            obj.IsBuilt = true;
        end

        function update(obj, state)
            % Sections: occupied red / locked yellow / idle gray
            route = obj.Topology.routes(1);
            for k = 1:numel(obj.Topology.sections)
                id = obj.Topology.sections(k).id;
                if ~isfield(obj.SectionLines, id), continue; end
                if isfield(state.trackOccupancy, id) && state.trackOccupancy.(id)
                    set(obj.SectionLines.(id), 'Color', [0.90 0.18 0.10]);
                elseif obj.isRouteLocked(state, route)
                    set(obj.SectionLines.(id), 'Color', [1.00 0.94 0.18]);
                else
                    set(obj.SectionLines.(id), 'Color', [0.55 0.60 0.66]);
                end
            end

            % Switches: lock highlights the branch used by the route
            for k = 1:numel(obj.SwitchKeys)
                id = obj.SwitchKeys{k};
                locked = isfield(state.switchPosition, id) && ...
                    strcmp(state.switchPosition.(id), 'locked-candidate');
                if locked
                    set(obj.SwitchNormal.(id), 'Color', [0.45 0.50 0.56], 'LineWidth', 3);
                    set(obj.SwitchReverse.(id), 'Color', [1.00 0.94 0.18], 'LineWidth', 4);
                else
                    set(obj.SwitchNormal.(id), 'Color', [0.55 0.60 0.66], 'LineWidth', 3);
                    set(obj.SwitchReverse.(id), 'Color', [0.55 0.60 0.66], 'LineWidth', 3);
                end
            end

            % Signals: shunting-open moon-white / closed red / dark
            for k = 1:numel(obj.SignalKeys)
                id = obj.SignalKeys{k};
                aspect = 'closed';
                if isfield(state.signalAspect, id)
                    aspect = state.signalAspect.(id);
                end
                switch aspect
                    case 'shunting-open'
                        set(obj.SignalHeads.(id), 'FaceColor', [0.95 0.96 1.00]);
                    case 'closed'
                        set(obj.SignalHeads.(id), 'FaceColor', [0.92 0.15 0.10]);
                    otherwise
                        set(obj.SignalHeads.(id), 'FaceColor', [0.20 0.24 0.30]);
                end
            end

            % Train pose from shared position
            [x, y, theta] = obj.trainPose(state.positionM);
            obj.moveTrain(x, y, theta);
            set(obj.TrainText, 'Position', [x y - 34]);

            drawnow limitrate;
        end

        function [x, y, theta] = trainPose(obj, positionM)
            pts = obj.RoutePoly;
            cum = obj.RouteCum;
            total = cum(end);
            q = min(max(positionM / obj.RouteLengthM * total, 0), total);
            x = interp1(cum, pts(:, 1), q, 'linear');
            y = interp1(cum, pts(:, 2), q, 'linear');

            % tangent direction at the train location
            dq = max(1, total / 500);
            qa = min(max(q - dq, 0), total);
            qb = min(max(q + dq, 0), total);
            xa = interp1(cum, pts(:, 1), qa, 'linear');
            ya = interp1(cum, pts(:, 2), qa, 'linear');
            xb = interp1(cum, pts(:, 1), qb, 'linear');
            yb = interp1(cum, pts(:, 2), qb, 'linear');
            theta = atan2(yb - ya, xb - xa);
        end
    end

    methods (Access = private)
        function buildStatic(obj)
            ax = obj.Ax;
            cla(ax);
            ax.Color = [0.03 0.04 0.07];
            ax.XColor = 'none';
            ax.YColor = 'none';
            ax.XLim = [0 1423];
            ax.YLim = [0 177];
            ax.YDir = 'reverse';
            ax.NextPlot = 'add';
            axis(ax, 'manual');

            g = obj.Topology.displayGeometry;

            % Section polylines (one line object per section)
            for k = 1:numel(obj.Topology.sections)
                id = obj.Topology.sections(k).id;
                if ~isfield(g.sections, id), continue; end
                pts = g.sections.(id);
                h = plot(ax, pts(:, 1), pts(:, 2), '-', ...
                    'Color', [0.55 0.60 0.66], 'LineWidth', 5, ...
                    'Marker', 'none');
                obj.SectionLines.(id) = h;
            end

            % Section name labels
            for k = 1:numel(obj.Topology.sections)
                id = obj.Topology.sections(k).id;
                if ~isfield(g.labels, id), continue; end
                p = g.labels.(id);
                obj.SectionLabels.(id) = text(ax, p(1), p(2), id, ...
                    'Color', [0.90 0.93 1.00], 'FontSize', 10, ...
                    'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', ...
                    'BackgroundColor', [0.03 0.04 0.07], 'Margin', 2);
            end

            % Switch fork geometry: direct branch (normal) and route
            % branch (reverse), derived from the display geometry only.
            ids = fieldnames(g.switches);
            obj.SwitchKeys = ids;
            for k = 1:numel(ids)
                id = ids{k};
                p = g.switches.(id);
                obj.SwitchPivots.(id) = p;
                [n1, r1] = obj.switchBranches(id, p);
                hn = plot(ax, n1(:, 1), n1(:, 2), '-', ...
                    'Color', [0.55 0.60 0.66], 'LineWidth', 3);
                hr = plot(ax, r1(:, 1), r1(:, 2), '-', ...
                    'Color', [0.55 0.60 0.66], 'LineWidth', 3);
                obj.SwitchNormal.(id) = hn;
                obj.SwitchReverse.(id) = hr;
                plot(ax, p(1), p(2), 'o', 'MarkerSize', 7, ...
                    'MarkerFaceColor', [0.75 0.80 0.88], ...
                    'MarkerEdgeColor', [0.30 0.34 0.40], 'LineWidth', 1.5);
            end

            % Signal heads (lamp circle per signal)
            sigIds = fieldnames(g.signals);
            obj.SignalKeys = sigIds;
            for k = 1:numel(sigIds)
                id = sigIds{k};
                p = g.signals.(id);
                th = linspace(0, 2 * pi, 30);
                obj.SignalHeads.(id) = patch(ax, ...
                    p(1) + 10 * cos(th), p(2) + 10 * sin(th), ...
                    [0.20 0.24 0.30], 'EdgeColor', [0.45 0.50 0.58], ...
                    'LineWidth', 1.5);
                text(ax, p(1), p(2) - 16, id, 'Color', [0.75 0.82 0.90], ...
                    'FontSize', 9, 'HorizontalAlignment', 'center', ...
                    'FontName', 'Microsoft YaHei UI');
            end

            % Train: rectangular patch with orientation
            x0 = 0; y0 = 158; th0 = 0;
            obj.TrainPatch = patch(ax, NaN, NaN, [0.15 0.45 0.95], ...
                'EdgeColor', [0.92 0.96 1.00], 'LineWidth', 1.8, ...
                'FaceAlpha', 0.95);
            obj.moveTrain(x0, y0, th0);
            obj.TrainText = text(ax, x0, y0 - 34, '车列', ...
                'Color', [0.92 0.96 1.00], 'FontSize', 10, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                'FontName', 'Microsoft YaHei UI', ...
                'BackgroundColor', [0.03 0.04 0.07], 'Margin', 2);
        end

        function buildRouteGeometry(obj)
            route = obj.Topology.routes(1);
            g = obj.Topology.displayGeometry;
            pts = [];
            for k = 1:numel(route.sections)
                id = route.sections{k};
                if ~isfield(g.sections, id), continue; end
                p = g.sections.(id);
                if isempty(pts)
                    pts = p;
                else
                    pts = [pts; p(2:end, :)]; %#ok<AGROW>
                end
            end
            obj.RoutePoly = pts;
            d = sqrt(sum(diff(pts, 1, 1).^2, 2));
            obj.RouteCum = [0; cumsum(d)];

            ax = obj.Ax;
            obj.RouteLine = plot(ax, pts(:, 1), pts(:, 2), '-', ...
                'Color', [1.00 0.94 0.18], 'LineWidth', 2.5, ...
                'Visible', 'off');
        end

        function [n1, r1] = switchBranches(obj, id, p)
            % Direct branch: continue along the incoming direction.
            % Route branch: connect to the next route vertex.
            g = obj.Topology.displayGeometry;
            n1 = [p(1) - 40, p(2); p(1) + 40, p(2)];

            % Find next point of the route after the switch pivot
            route = obj.Topology.routes(1);
            nxt = [];
            for k = 1:numel(route.sections)
                sec = g.sections.(route.sections{k});
                for m = 1:size(sec, 1)
                    if norm(sec(m, :) - p) < 2
                        if m < size(sec, 1)
                            nxt = sec(m + 1, :);
                        end
                        break;
                    end
                end
                if ~isempty(nxt), break; end
            end
            if isempty(nxt)
                nxt = [p(1) + 40, p(2) - 20];
            end
            r1 = [p; nxt];
        end

        function tf = isRouteLocked(obj, state, route)
            tf = false;
            if ~isfield(state, 'scenarioState'), return; end
            lockedStates = { ...
                'ROUTE_LOCKED', 'SHUNT_SIGNAL_OPEN', 'TRAIN_ENTERED_ROUTE', ...
                'OCCUPANCY_TRANSFER', 'THROAT_PASSING', 'ENTERED_TARGET_TRACK', ...
                'TARGET_BRAKING', 'STOP_CONFIRMED'};
            tf = any(strcmp(state.scenarioState, lockedStates));
        end

        function moveTrain(obj, x, y, theta)
            L = 46; W = 18;
            c = cos(theta); s = sin(theta);
            corners = [-L/2 -W/2; L/2 -W/2; L/2 W/2; -L/2 W/2];
            rot = [c -s; s c];
            cx = corners * rot' + [x y];
            set(obj.TrainPatch, 'XData', cx(:, 1), 'YData', cx(:, 2));
        end
    end
end
