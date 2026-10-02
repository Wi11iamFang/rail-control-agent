classdef MinimalTrainPlant < handle
    % MinimalTrainPlant
    % A tiny single-mass train model for the DMI shunting demonstration.
    % Inputs are notch and service/emergency brake flags; outputs are speed,
    % acceleration and position. Units are SI internally.

    properties
        PositionM = 0
        VelocityMps = 0
        AccelMps2 = 0
        MassKg = 40000
        MaxTractionN = 90000
        MaxBrakeN = 65000
        ResistanceA = 900
        ResistanceB = 28
        ResistanceC = 4
    end

    methods
        function reset(obj, positionM)
            if nargin < 2
                positionM = 0;
            end
            obj.PositionM = positionM;
            obj.VelocityMps = 0;
            obj.AccelMps2 = 0;
        end

        function state = step(obj, notch, serviceBrake, emergencyBrake, dt)
            notch = max(-3, min(3, round(notch)));
            traction = 0;
            brake = 0;

            if notch > 0
                traction = obj.MaxTractionN * notch / 3;
            elseif notch < 0
                brake = obj.MaxBrakeN * abs(notch) / 3;
            end

            if serviceBrake
                brake = max(brake, obj.MaxBrakeN * 0.60);
            end
            if emergencyBrake
                brake = obj.MaxBrakeN * 1.20;
                traction = 0;
            end

            resistance = obj.ResistanceA + obj.ResistanceB * abs(obj.VelocityMps) ...
                + obj.ResistanceC * obj.VelocityMps^2;
            if obj.VelocityMps < 0.02 && traction <= resistance
                resistance = traction;
            end

            force = traction - brake - resistance;
            obj.AccelMps2 = force / obj.MassKg;
            obj.VelocityMps = max(0, obj.VelocityMps + obj.AccelMps2 * dt);
            obj.PositionM = obj.PositionM + obj.VelocityMps * dt;

            state.positionM = obj.PositionM;
            state.velocityMps = obj.VelocityMps;
            state.speedKmh = obj.VelocityMps * 3.6;
            state.accelMps2 = obj.AccelMps2;
        end
    end
end
