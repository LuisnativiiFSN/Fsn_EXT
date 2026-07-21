codeunit 50083 Test
{
    TableNo = "LSC Scheduler Job Header";
    trigger OnRun()
    var
        pqty: decimal;

    begin
        pqty := Round((4 / 10), 1, '=');
        Message('Test ', Format(pqty));

    end;
}