classdef YardViewRenderer < handle
    %YARDVIEWRENDERER Vector yard renderer shared by the three ends.
    %   Renders the candidate local topology as vector graphics objects once,
    %   then updates only their properties from the shared state. Matches the
    %   reference line-plan look: double-rail sections, three-branch switches,
    %   colour-light signals, round-nose train with train number.
    %
    %   Display only: never writes to the shared state.

    properties
        Ax            % uiaxes
        Topology      % RouteTopology struct
        RouteLengthM = 420  % demo mapping: positionM -> full route length
        SignalBlink = false % blink open signal (big screen only)
    end

    properties (Access = private)
        SectionLinesA  % struct: id -> line handle (rail A)
        SectionLinesB  % struct: id -> line handle (rail B)
        SectionLabels  % struct: id -> text handle
        SwitchNormal   % struct: id -> line handle (direct branch)
        SwitchReverse  % struct: id -> line handle (route branch)
        SwitchPivots   % struct: id -> [x y]
        SwitchKeys     % cell of switch ids
        SignalHeads    % struct: id -> patch handle (signal lamp)
        SignalKeys     % cell of signal ids
        RoutePoly      % [N x 2] polyline of the candidate route
        RouteCum       % cumulative pixel length
        RouteLine      % line handle for route highlight
        TrainPatch     % patch handle for the train
        TrainText      % text handle: train number
        SignalBlinkOn  % current blink phase
        IsBuilt = false
    end

    % Colours (matching reference interlocking look)
    properties (Constant, Access = private)
        COL_BG        = [0.02 0.03 0.06]
        COL_RAIL_IDLE = [0.62 0.68 0.75]
        COL_RAIL_OCC  = [0.94 0.22 0.12]
        COL_RAIL_LOCK = [1.00 0.92 0.20]
        COL_RAIL_DIM  = [0.42 0.48 0.55]
        COL_SIGNAL_OPEN = [0.95 0.96 1.00]
        COL_SIGNAL_CLOSED = [0.92 0.16 0.10]
        COL_SIGNAL_DARK  = [0.22 0.26 0.32]
        COL_TEXT       = [0.92 0.96 1.00]
        COL_TEXT_DIM   = [0.78 0.84 0.90]
    end

    methods
        function obj = YardViewRenderer(ax, topology)
            obj.Ax = ax;
            obj.Topology = topology;
            obj.SignalBlink = false;
            obj.SignalBlinkOn = true;
            obj.buildStatic();
            obj.buildRouteGeometry();
            obj.IsBuilt = true;
        end

        function update(obj, state)
            % Sections: occupied red / locked yellow / idle gray
            route = obj.Topology.routes(1);
            locked = obj.isRouteLocked(state, route);
            for k = 1:numel(obj.Topology.sections)
                id = obj.Topology.sections(k).id;
                if ~isfield(obj.SectionLinesA, id), continue; end
                if isfield(state.trackOccupancy, id) && state.trackOccupancy.(id)
                    set(obj.SectionLinesA.(id), 'Color', obj.COL_RAIL_OCC, 'LineWidth', 6);
                    set(obj.SectionLinesB.(id), 'Color', obj.COL_RAIL_OCC, 'LineWidth', 6);
                elseif locked
                    set(obj.SectionLinesA.(id), 'Color', obj.COL_RAIL_LOCK, 'LineWidth', 6);
                    set(obj.SectionLinesB.(id), 'Color', obj.COL_RAIL_LOCK, 'LineWidth', 6);
                else
                    set(obj.SectionLinesA.(id), 'Color', obj.COL_RAIL_IDLE, 'LineWidth', 4);
                    set(obj.SectionLinesB.(id), 'Color', obj.COL_RAIL_IDLE, 'LineWidth', 4);
                end
            end

            % Switches: lock highlights the branch used by the route
            for k = 1:numel(obj.SwitchKeys)
                id = obj.SwitchKeys{k};
                swLocked = isfield(state.switchPosition, id) && ...
                    strcmp(state.switchPosition.(id), 'locked-candidate');
                if swLocked
                    set(obj.SwitchNormal.(id), 'Color', obj.COL_RAIL_DIM, 'LineWidth', 4);
                    set(obj.SwitchReverse.(id), 'Color', obj.COL_RAIL_LOCK, 'LineWidth', 5);
                else
                    set(obj.SwitchNormal.(id), 'Color', obj.COL_RAIL_IDLE, 'LineWidth', 3);
                    set(obj.SwitchReverse.(id), 'Color', obj.COL_RAIL_IDLE, 'LineWidth', 3);
                end
            end

            % Signals: shunting-open moon-white (blink if enabled) / closed red / dark
            obj.SignalBlinkOn = ~obj.SignalBlinkOn;
            for k = 1:numel(obj.SignalKeys)
                id = obj.SignalKeys{k};
                aspect = 'closed';
                if isfield(state.signalAspect, id)
                    aspect = state.signalAspect.(id);
                end
                switch aspect
                    case 'shunting-open'
                        if obj.SignalBlink && ~obj.SignalBlinkOn
                            set(obj.SignalHeads.(id), 'FaceColor', obj.COL_SIGNAL_DARK);
                        else
                            set(obj.SignalHeads.(id), 'FaceColor', obj.COL_SIGNAL_OPEN);
                        end
                    case 'closed'
                        set(obj.SignalHeads.(id), 'FaceColor', obj.COL_SIGNAL_CLOSED);
                    otherwise
                        set(obj.SignalHeads.(id), 'FaceColor', obj.COL_SIGNAL_DARK);
                end
            end

            % Route highlight visible when locked, dim but present otherwise
            if locked
                set(obj.RouteLine, 'Visible', 'on', 'Color', obj.COL_RAIL_LOCK, 'LineWidth', 3);
            else
                set(obj.RouteLine, 'Visible', 'on', 'Color', obj.COL_RAIL_LOCK * 0.35, 'LineWidth', 1.5);
            end

            % Train pose from shared position
            [x, y, theta] = obj.trainPose(state.positionM);
            obj.moveTrain(x, y, theta);
            set(obj.TrainText, 'Position', [x y - 30]);

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
            ax.Color = obj.COL_BG;
            ax.XColor = 'none';
            ax.YColor = 'none';
            ax.XLim = [0 1423];
            ax.YLim = [0 177];
            ax.YDir = 'reverse';
            ax.NextPlot = 'add';
            axis(ax, 'manual');

            g = obj.Topology.displayGeometry;

            % --- Section: double rails (offset perpendicular to segment) ---
            for k = 1:numel(obj.Topology.sections)
                id = obj.Topology.sections(k).id;
                if ~isfield(g.sections, id), continue; end
                pts = g.sections.(id);
                [ra, rb] = obj.parallelRails(pts, 4);
                ha = plot(ax, ra(:, 1), ra(:, 2), '-', ...
                    'Color', obj.COL_RAIL_IDLE, 'LineWidth', 4, 'Marker', 'none');
                hb = plot(ax, rb(:, 1), rb(:, 2), '-', ...
                    'Color', obj.COL_RAIL_IDLE, 'LineWidth', 4, 'Marker', 'none');
                obj.SectionLinesA.(id) = ha;
                obj.SectionLinesB.(id) = hb;
            end

            % --- Section name labels (between rails) ---
            for k = 1:numel(obj.Topology.sections)
                id = obj.Topology.sections(k).id;
                if ~isfield(g.labels, id), continue; end
                p = g.labels.(id);
                obj.SectionLabels.(id) = text(ax, p(1), p(2), id, ...
                    'Color', obj.COL_TEXT, 'FontSize', 10, ...
                    'FontWeight', 'bold', 'FontName', 'Microsoft YaHei UI', ...
                    'BackgroundColor', [0.02 0.03 0.06], 'Margin', 3, ...
                    'HorizontalAlignment', 'center');
            end

            % --- Switches: three-direction fork ---
            ids = fieldnames(g.switches);
            obj.SwitchKeys = ids;
            for k = 1:numel(ids)
                id = ids{k};
                p = g.switches.(id);
                obj.SwitchPivots.(id) = p;
                [n1, r1] = obj.switchBranches(id, p);
                hn = plot(ax, n1(:, 1), n1(:, 2), '-', ...
                    'Color', obj.COL_RAIL_IDLE, 'LineWidth', 3);
                hr = plot(ax, r1(:, 1), r1(:, 2), '-', ...
                    'Color', obj.COL_RAIL_IDLE, 'LineWidth', 3);
                obj.SwitchNormal.(id) = hn;
                obj.SwitchReverse.(id) = hr;
                plot(ax, p(1), p(2), 'o', 'MarkerSize', 8, ...
                    'MarkerFaceColor', [0.80 0.85 0.92], ...
                    'MarkerEdgeColor', [0.35 0.40 0.46], 'LineWidth', 2);
            end

            % --- Signal heads (colour lights) ---
            sigIds = fieldnames(g.signals);
            obj.SignalKeys = sigIds;
            for k = 1:numel(sigIds)
                id = sigIds{k};
                p = g.signals.(id);
                th = linspace(0, 2 * pi, 32);
                obj.SignalHeads.(id) = patch(ax, ...
                    p(1) + 11 * cos(th), p(2) + 11 * sin(th), ...
                    obj.COL_SIGNAL_DARK, 'EdgeColor', [0.55 0.60 0.66], ...
                    'LineWidth', 1.8);
                text(ax, p(1), p(2) + 20, id, 'Color', obj.COL_TEXT_DIM, ...
                    'FontSize', 10, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'FontName', 'Microsoft YaHei UI');
            end

            % --- Train: round-nose car body with train number ---
            x0 = 0; y0 = 158; th0 = 0;
            obj.TrainPatch = patch(ax, [0 0 0 0], [0 0 0 0], ...
                [0.13 0.42 0.92], 'EdgeColor', [0.92 0.96 1.00], ...
                'LineWidth', 2.0, 'FaceAlpha', 0.96);
            obj.moveTrain(x0, y0, th0);
            obj.TrainText = text(ax, x0, y0 - 30, 'D2', ...
                'Color', [1 1 1], 'FontSize', 12, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                'FontName', 'Microsoft YaHei UI', ...
                'BackgroundColor', [0.13 0.42 0.92], 'Margin', 3);

            % --- Fit the view to the data aspect (no distortion) ---
            obj.fitAxesToAspect();
        end

        function fitAxesToAspect(obj)
            % Adjust XLim/YLlim so the visible data window matches the axes
            % pixel aspect, preventing horizontal/vertical stretching when
            % the same renderer is used in differently-shaped axes (yard
            % banner vs ground panel). Data range 1423 x 177 (8.04:1).
            ax = obj.Ax;
            axp = get(ax, 'Position');
            axW = axp(3); axH = axp(4);
            if axH <= 0, return; end
            axAspect = axW / axH;
            dataAspect = 1423 / 177;

            if axAspect >= dataAspect
                % axes wider than data: fit by width, center vertically
                xlim = [0 1423];
                spanY = 1423 / axAspect;
                ymid = 177 / 2;
                ylim = [ymid - spanY / 2, ymid + spanY / 2];
            else
                % axes taller than data: fit by height, center horizontally
                ylim = [0 177];
                spanX = 177 * axAspect;
                xmid = 1423 / 2;
                xlim = [xmid - spanX / 2, xmid + spanX / 2];
            end
            ax.XLim = xlim;
            ax.YLim = ylim;
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
                'Color', obj.COL_RAIL_LOCK * 0.35, 'LineWidth', 1.5, ...
                'Visible', 'on');
        end

        function [ra, rb] = parallelRails(obj, pts, off)
            % Offset each vertex perpendicular to the segment direction,
            % producing two parallel rails ~2*off apart (reference look).
            n = size(pts, 1);
            ra = pts; rb = pts;
            for i = 1:n
                if i < n
                    v = pts(i + 1, :) - pts(i, :);
                else
                    v = pts(i, :) - pts(i - 1, :);
                end
                len = norm(v);
                if len < 1e-6
                    v = [1 0];
                else
                    v = v / len;
                end
                nv = [-v(2), v(1)] * off;
                ra(i, :) = pts(i, :) + nv;
                rb(i, :) = pts(i, :) - nv;
            end
        end

        function [n1, r1] = switchBranches(obj, id, p)
            % Direct branch: continue along the incoming direction.
            % Route branch: connect to the next route vertex.
            g = obj.Topology.displayGeometry;
            n1 = [p(1) - 40, p(2); p(1) + 40, p(2)];

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
            L = 56; W = 22; R = W / 2;          % body length/width, nose radius
            noseStartX = L / 2 - R;
            % rounded-nose rectangle polygon (centered at origin)
            arcA = linspace(pi / 2, -pi / 2, 24);  % front nose arc
            X = [-L/2, noseStartX, ...            % back-top to nose-top
                 noseStartX + R * cos(arcA), ...  % nose arc (top -> bottom)
                 noseStartX, -L/2];               % nose-bottom to back-bottom
            Y = [W/2, W/2, ...                    % top edge
                 R * sin(arcA), ...               % nose arc
                 -W/2, -W/2];                     % bottom edge
            rot = [cos(theta) -sin(theta); sin(theta) cos(theta)];
            local = [X(:), Y(:)];
            pts = local * rot' + [x y];
            set(obj.TrainPatch, 'XData', pts(:, 1), 'YData', pts(:, 2));
        end
    end
end