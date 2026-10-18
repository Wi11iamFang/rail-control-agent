% Launch the three-ended shunting prototype from this workspace.
% Ends: GroundControlApp (operator) + YardViewApp (shunting big screen)
%       + RemoteDMIApp (onboard DMI), all driven by one shared context.
% Run this script from any working directory; it fixes up the path itself.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);

% Put the shared src directory on the path (relative to launch/).
srcDir = fullfile(thisDir, '..', 'src');
if ~contains(path, srcDir)
    addpath(srcDir);
end

% Never load legacy demo classes from the old outputs folder.
oldOutputDir = fullfile(thisDir, 'outputs');
if contains(path, oldOutputDir)
    rmpath(oldOutputDir);
end

rehash

disp('Loading RemoteDMIApp, GroundControlApp, YardViewApp from:')
which RemoteDMIApp
which GroundControlApp
which YardViewApp

% One in-process shared context; no TCP/UDP transport is used.
topology = RouteTopology.createLocalCandidate();
state = RemoteOperationState.initial(topology);
plant = MinimalTrainPlant();
sharedContext = RemoteOperationContext(topology, state, plant);

% Single business driver owns all state transitions.
sharedContext.Driver = ShuntDriver(sharedContext);

groundApp = GroundControlApp(sharedContext);
yardApp = YardViewApp(sharedContext);
onboardApp = RemoteDMIApp(sharedContext);