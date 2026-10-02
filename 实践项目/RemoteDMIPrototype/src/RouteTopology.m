classdef RouteTopology
    %ROUTETOPOLOGY Local candidate topology for the shunting prototype.
    %   This class stores a small display-oriented topology extracted from
    %   the local reference drawing. It is not a verified interlocking
    %   route table; unconfirmed objects remain explicitly marked.

    methods (Static)
        function topology = createLocalCandidate()
            topology = struct();
            topology.id = 'LOCAL_CANDIDATE_C21_D20';
            topology.name = 'C21G1 to D20 direction candidate route';
            topology.confirmationStatus = 'candidate';
            topology.source = '实践项目/_zhanlishitu_local.png';
            topology.imagePath = fullfile(fileparts(mfilename('fullpath')), '..', '..', '_zhanlishitu_local.png');
            topology.imageSizePx = [1423, 177];
            topology.displayCoordinateSystem = 'PNG pixel coordinates, origin at upper-left';
            topology.note = 'Temporary display topology pending formal route data confirmation.';

            topology.sections = RouteTopology.sections();
            topology.displayGeometry = RouteTopology.displayGeometry();
            topology.switches = RouteTopology.switches();
            topology.signals = RouteTopology.signals();
            topology.routes = RouteTopology.routes();
        end
    end

    methods (Static, Access = private)
        function sections = sections()
            sections = struct('id', {}, 'name', {}, 'type', {}, ...
                'lengthM', {}, 'isReal', {}, 'confirmationStatus', {});

            sections(end + 1) = struct('id', 'C21G1', ...
                'name', 'C21G1', 'type', 'track', 'lengthM', NaN, ...
                'isReal', true, 'confirmationStatus', 'drawing-label');
            sections(end + 1) = struct('id', 'THROAT_LOCAL_1', ...
                'name', 'Local throat section 1', 'type', 'throat', 'lengthM', NaN, ...
                'isReal', false, 'confirmationStatus', 'placeholder');
            sections(end + 1) = struct('id', 'THROAT_LOCAL_2', ...
                'name', 'Local throat section 2', 'type', 'throat', 'lengthM', NaN, ...
                'isReal', false, 'confirmationStatus', 'placeholder');
            sections(end + 1) = struct('id', 'D20_APPROACH', ...
                'name', 'D20 direction approach', 'type', 'approach', 'lengthM', NaN, ...
                'isReal', false, 'confirmationStatus', 'candidate');
        end

        function switches = switches()
            switches = struct('id', {}, 'position', {}, 'requiredPosition', {}, ...
                'locked', {}, 'isReal', {}, 'confirmationStatus', {});

            switches(end + 1) = struct('id', 'W_LOCAL_1', ...
                'position', 'unknown', 'requiredPosition', 'to-confirm', ...
                'locked', false, 'isReal', false, 'confirmationStatus', 'placeholder');
            switches(end + 1) = struct('id', 'W_LOCAL_2', ...
                'position', 'unknown', 'requiredPosition', 'to-confirm', ...
                'locked', false, 'isReal', false, 'confirmationStatus', 'placeholder');
        end

        function signals = signals()
            signals = struct('id', {}, 'name', {}, 'type', {}, ...
                'aspect', {}, 'isReal', {}, 'confirmationStatus', {});

            signals(end + 1) = struct('id', 'XC21', ...
                'name', 'XC21', 'type', 'shunting', 'aspect', 'closed', ...
                'isReal', true, 'confirmationStatus', 'drawing-label');
            signals(end + 1) = struct('id', 'D20', ...
                'name', 'D20', 'type', 'signal-or-device', 'aspect', 'unknown', ...
                'isReal', true, 'confirmationStatus', 'drawing-label');
        end

        function routes = routes()
            routes = struct('id', {}, 'startSignal', {}, 'sections', {}, ...
                'switches', {}, 'target', {}, 'releaseMode', {}, ...
                'confirmationStatus', {});

            routes(end + 1) = struct( ...
                'id', 'R_C21_D20_CANDIDATE', ...
                'startSignal', 'XC21', ...
                'sections', {{'C21G1', 'THROAT_LOCAL_1', 'THROAT_LOCAL_2', 'D20_APPROACH'}}, ...
                'switches', {{'W_LOCAL_1', 'W_LOCAL_2'}}, ...
                'target', 'D20_APPROACH', ...
                'releaseMode', 'to-confirm', ...
                'confirmationStatus', 'candidate');
        end

        function geometry = displayGeometry()
            % Coordinates are image pixels from _zhanlishitu_local.png.
            % They are display anchors only, not verified railway data.
            geometry = struct();
            geometry.imageSizePx = [1423, 177];
            geometry.sections = struct();
            geometry.sections.C21G1 = [0, 158; 210, 158];
            geometry.sections.THROAT_LOCAL_1 = [210, 158; 505, 158; 670, 116];
            geometry.sections.THROAT_LOCAL_2 = [670, 116; 835, 116; 1015, 47];
            geometry.sections.D20_APPROACH = [1015, 47; 1240, 47; 1420, 12];
            geometry.signals = struct('XC21', [249, 157], 'D20', [863, 121], 'D16', [1384, 52]);
            geometry.switches = struct('W_LOCAL_1', [505, 158], 'W_LOCAL_2', [835, 116]);
            geometry.labels = struct('C21G1', [15, 157], 'THROAT_LOCAL_1', [530, 145], ...
                'THROAT_LOCAL_2', [760, 104], 'D20_APPROACH', [1090, 35]);
            geometry.confirmationStatus = 'display-only-candidate';
        end
    end
end
