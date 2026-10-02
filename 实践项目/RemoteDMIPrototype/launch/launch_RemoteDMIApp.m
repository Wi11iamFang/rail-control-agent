% Launch the interactive DMI prototype from this workspace.
% Run this script instead of adding the outputs folder to the MATLAB path.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
cd(thisDir);

oldOutputDir = fullfile(thisDir, 'outputs');
if contains(path, oldOutputDir)
    rmpath(oldOutputDir);
end

clear classes
rehash

disp('Loading RemoteDMIApp and GroundControlApp from:')
which RemoteDMIApp
which GroundControlApp

% One in-process shared context; no TCP/UDP transport is used.
topology = RouteTopology.createLocalCandidate();
state = RemoteOperationState.initial(topology);
plant = MinimalTrainPlant();
sharedContext = RemoteOperationContext(topology, state, plant);

groundApp = GroundControlApp(sharedContext);
onboardApp = RemoteDMIApp(sharedContext);
