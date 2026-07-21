codeunit 50057 "FSN Retention Policy"
{
    trigger OnRun()
    var
        JobQueueEntry: Record "Job Queue Entry";
        fsnParam: Record "FSN Parameter";
    begin
        if fsnParam.Get('RETPOLICY', 'POLICY1') then begin
            if fsnParam.Activo then begin
                JobQueueEntry.Reset();
                JobQueueEntry.SetFilter("Object ID to Run", '<>%1&<>%2&<>%3&<>%4&<>%5&<>%6&<>%7', 297, 298, 497, 498, 3997, 50057, 50084);
                JobQueueEntry.SetRange("Status", JobQueueEntry."Status"::Error);
                JobQueueEntry.SetRange(SystemCreatedAt, CreateDateTime(CalcDate('<' + fsnParam."Value Text 1" + '>', WORKDATE), Time), CreateDateTime(CalcDate('<' + fsnParam."Value Text 2" + '>', WORKDATE), Time));
                if JobQueueEntry.FindFirst() then begin
                    repeat
                        JobQueueEntry.Delete();
                    until JobQueueEntry.Next() = 0;
                end;
            end;
        end;
    end;
}