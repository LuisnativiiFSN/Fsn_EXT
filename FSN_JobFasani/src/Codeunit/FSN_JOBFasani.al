codeunit 50041 "FSN JOB Fasani"
{
    SingleInstance = true;
    trigger OnRun()
    begin
    end;

    var
        myInt: Integer;

    [ServiceEnabled]
    procedure GetJob(): Boolean
    var
        myInt: Integer;
        FsnJob: Record "FSN Scheduler Job Header";
        ok: Boolean;
        VTime: Time;
    begin
        FsnJob.Reset();
        if FsnJob.Find('-') then
            if FsnJob."Job ID" <> '' then
                repeat
                    ok := ReadCodeunit(FsnJob."Job ID");
                until FsnJob.Next() = 0;
        exit(ok);
    end;

    local procedure ReadCodeunit(Id: Code[20]): Boolean
    var
        FsnJob, FsnJobRun : Record "FSN Scheduler Job Header";
        Job: Record "LSC Scheduler Job Header";
        ok: Boolean;
    begin
        if FsnJob.Get(Id) then begin
            if ValidateStatus(FsnJob) then begin
                ValidateParameter(FsnJob);
                if FsnJob."Uses Scheduler Job Record" then begin
                    Job.Init();
                    Job.Text := FsnJob.Text;
                    Job.Code := FsnJob.Code;
                    Job.Integer := FsnJob.Integer;
                    Job.Decimal := FsnJob.Decimal;
                    Job.Date := FsnJob.Date;
                    Job.Time := FsnJob.Time;
                    Job.Boolean := FsnJob.Boolean;
                    Job.DateFormula := FsnJob.DateFormula;
                    Codeunit.Run(FsnJob."Object No.", Job);
                    AfterRunCodeunit(FsnJob, Job);
                end else begin
                    Commit();
                    if FsnJobRun.Get(FsnJob."Job ID") then
                        if Codeunit.Run(FsnJobRun."Object No.") then;
                    AfterRunCodeunit(FsnJobRun, Job);
                end;
                exit(true);
            end else
                exit(false);
        end;
    end;

    local procedure ValidateParameter(FsnJob: Record "FSN Scheduler Job Header")
    var
        ParameterFSN: Record "FSN Parameter";
        Change: Boolean;
    begin
        ParameterFSN.Reset();
        ParameterFSN.SetRange(Grupo, 'CONF');
        ParameterFSN.SetRange(Codigo, 'STATEMENT');
        ParameterFSN.SetRange(Activo, true);
        if ParameterFSN.FindSet() then begin
            if ParameterFSN.Descripcion <> FsnJob.Text then
                Change := true;
            if ParameterFSN."Value Text 1" <> Format(FsnJob.DateFormula) then
                Change := true;
            if ParameterFSN.Valor <> FsnJob.Code then
                Change := true;
            ParameterFSN."Lookup ID 1" := Format(FsnJob."Ending Time");
            ParameterFSN.SetFilterData1 := Format(FsnJob."Ending Time");
            ParameterFSN."Lookup ID 2" := Format(FsnJob."Next Check Date");


            ParameterFSN.Descripcion := FsnJob.Text;
            ParameterFSN."Value Text 1" := Format(FsnJob.DateFormula);
            ParameterFSN.Valor := FsnJob.Code;
            ParameterFSN.Modify(true);

        end;
    end;

    local procedure ValidateStatus(FsnJob: Record "FSN Scheduler Job Header"): Boolean
    var
        myInt: Integer;
        FsnJob2: Record "FSN Scheduler Job Header";

    begin
        if (FsnJob."Run Status" = FsnJob."Run Status"::Processing) then begin
            ValidateLasEjecution(FsnJob);
            exit(false)
        end else
            if FsnJob2.Get(FsnJob."Job ID") then begin
                IF InTimePeriod(FsnJob, Time) and (ValidateDate(FsnJob)) then begin
                    FsnJob2."Run Status" := FsnJob2."Run Status"::Processing;
                    FsnJob2."Last Date Checked" := Today;
                    FsnJob2."Last Time Checked" := Time;
                    FsnJob2."Retry Counter" := FsnJob2."Retry Counter" + 1;
                    FsnJob2.Modify();
                    exit(true);
                end else
                    exit(false);
            end;
    end;

    local procedure ValidateDate(SchedulerHeader: Record "FSN Scheduler Job Header"): Boolean
    var
        myInt: Integer;
        EmptyDateFormula: DateFormula;
        DateTimeNow: Decimal;
        Date_Time: Decimal;
        WeekDay: Integer;
        Iterations: Integer;
        WeekDayValid: Boolean;
    begin
        if SchedulerHeader."Next Check Date" = 0D then
            exit(WeekDayValid);
        WeekDay := Date2DWY(SchedulerHeader."Next Check Date", 1);
        WeekDayValid := false;
        Iterations := 0;
        while (not WeekDayValid) and (Iterations < 7) do begin
            case WeekDay of
                1:
                    if SchedulerHeader."Valid on Mondays" then
                        WeekDayValid := true;
                2:
                    if SchedulerHeader."Valid on Tuesdays" then
                        WeekDayValid := true;
                3:
                    if SchedulerHeader."Valid on Wednesdays" then
                        WeekDayValid := true;
                4:
                    if SchedulerHeader."Valid on Thursdays" then
                        WeekDayValid := true;
                5:
                    if SchedulerHeader."Valid on Fridays" then
                        WeekDayValid := true;
                6:
                    if SchedulerHeader."Valid on Saturdays" then
                        WeekDayValid := true;
                7:
                    if SchedulerHeader."Valid on Sundays" then
                        WeekDayValid := true;
            end;
        end;
        exit(WeekDayValid);
    end;

    procedure ValidateLasEjecution(FsnJob2: Record "FSN Scheduler Job Header")
    var
        ActiveSession: Record "Active Session";
        Job: Record "LSC Scheduler Job Header";
        Ti: Time;
    begin
        Ti := Time;
        if FsnJob2."Ending Time" <= Time then begin
            ActiveSession.Reset();
            ActiveSession.SetRange("User ID", UserId);
            if ActiveSession.FindFirst() then
                ActiveSession.Delete();

            AfterRunCodeunit(FsnJob2, Job);
        end;
    end;

    local procedure InTimePeriod(var schHdr: Record "FSN Scheduler Job Header"; currTime: Time): Boolean
    var
        overlap: Boolean;
    begin
        overlap := (schHdr."Starting Time" < schHdr."Ending Time");

        if overlap then
            exit((currTime >= schHdr."Starting Time") and (currTime <= schHdr."Ending Time") and (schHdr."Next Check Date" <= today()))
        else
            exit((currTime >= schHdr."Starting Time") or (currTime <= schHdr."Ending Time") and (schHdr."Next Check Date" <= today()));
    end;

    local procedure AfterRunCodeunit(FsnJob: Record "FSN Scheduler Job Header"; Job: Record "LSC Scheduler Job Header"): Boolean
    var
        FsnJob2: Record "FSN Scheduler Job Header";
        lText001: Label 'Programa retorno un error';
    begin
        if Job."Error Occurred" then begin
            if FsnJob2.Get(FsnJob."Job ID") then begin
                FsnJob2."Run Status" := FsnJob2."Run Status"::"Stopped With Error";
                FsnJob2."Last Date Checked" := Today;
                FsnJob2."Last Time Checked" := Time;
                FsnJob2."Last Message Text" := lText001;
                FsnJob2."Retry Counter" := FsnJob2."Retry Counter" + 1;
                FsnJob2.Modify();
            END;
        END ELSE
            if FsnJob2.Get(FsnJob."Job ID") then begin
                FsnJob2."Run Status" := FsnJob2."Run Status"::" ";
                FsnJob2."Last Date Checked" := Today;
                FsnJob2."Last Time Checked" := Time;
                FsnJob2."Retry Counter" := FsnJob2."Retry Counter" + 1;
                CalcNewDateTime(FsnJob2."Next Check Date", FsnJob2."Next Check Time",
                                           FsnJob2."Time Between Check", FsnJob2."Time Units",
                                           FsnJob2."Calcdate Formula", FsnJob2);
                FsnJob2.Modify();
            end;
    end;

    local procedure CalcNewDateTime(var NextDate: Date; var NextTime: Time; Interval: Integer; Unit: Option Second,Minute,Hour,Day; CalcDateFormula: DateFormula; SchedulerHeader: Record "FSN Scheduler Job Header")
    var
        EmptyDateFormula: DateFormula;
        DateTimeNow: Decimal;
        Date_Time: Decimal;
        WeekDay: Integer;
        Iterations: Integer;
        WeekDayValid: Boolean;
    begin
        if Interval = 0 then begin
            NextDate := 0D;
            NextTime := 0T;
            exit;
        end;
        if NextDate = 0D then
            exit;
        Date_Time := ((NextDate - Today) * 86400) + Round((NextTime - 000000T) / 1000, 1);
        DateTimeNow := Round((Time - 000000T) / 1000, 1);
        case Unit of
            Unit::Second:
                Interval := Interval;
            Unit::Minute:
                Interval := Interval * 60;
            Unit::Hour:
                Interval := Interval * 3600;
            Unit::Day:
                Interval := Interval * 86400;
        end;

        while Date_Time <= DateTimeNow do
            Date_Time := Date_Time + Interval;

        if CalcDateFormula <> EmptyDateFormula then
            NextDate := CalcDate(CalcDateFormula, Today)
        else
            NextDate := Today + Round(Date_Time / 86400, 1.0, '<');

        NextTime := 000000T + (Date_Time - (Round(Date_Time / 86400, 1.0, '<') * 86400)) * 1000;

        if (SchedulerHeader."Ending Time" <> 0T) and (NextTime >= SchedulerHeader."Ending Time") then begin
            if SchedulerHeader."Starting Time" = 0T then
                NextTime := 000000T
            else
                NextTime := SchedulerHeader."Starting Time";
            NextDate += 1;
        end;

        WeekDay := Date2DWY(NextDate, 1);
        WeekDayValid := false;
        Iterations := 0;

        while (not WeekDayValid) and (Iterations < 7) do begin
            case WeekDay of
                1:
                    if SchedulerHeader."Valid on Mondays" then
                        WeekDayValid := true;
                2:
                    if SchedulerHeader."Valid on Tuesdays" then
                        WeekDayValid := true;
                3:
                    if SchedulerHeader."Valid on Wednesdays" then
                        WeekDayValid := true;
                4:
                    if SchedulerHeader."Valid on Thursdays" then
                        WeekDayValid := true;
                5:
                    if SchedulerHeader."Valid on Fridays" then
                        WeekDayValid := true;
                6:
                    if SchedulerHeader."Valid on Saturdays" then
                        WeekDayValid := true;
                7:
                    if SchedulerHeader."Valid on Sundays" then
                        WeekDayValid := true;
            end;
            if not WeekDayValid then begin
                WeekDay := (WeekDay mod 7) + 1;
                Iterations += 1;
            end;
        end;
        NextDate := NextDate + Iterations;
    end;
}

