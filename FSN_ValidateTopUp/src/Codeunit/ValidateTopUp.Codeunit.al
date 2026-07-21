codeunit 50034 "FSN Validate Top Up Total"
{
    var
        POSTransactionLineC: Record "LSC POS Trans. Line";
        POSTransactionC: Codeunit "LSC POS Transaction";

    procedure ValidateTopUpTotal(var POSTransaction: Record "LSC POS Transaction"; var Msg: Text): Boolean
    var
        Msg01: Label 'You can only perform one top-up per transaction';
        CurrTransLine: Record "LSC POS Trans. Line";
        Items: Record Item;
    begin
        CurrTransLine.Reset();
        CurrTransLine.SetRange(CurrTransLine."Receipt No.", POSTransaction."Receipt No.");
        CurrTransLine.SetRange(CurrTransLine."Entry Type", CurrTransLine."Entry Type"::Item);
        CurrTransLine.SetFilter(CurrTransLine."Entry Status", '<>%1', CurrTransLine."Entry Status"::Voided);
        CurrTransLine.SetFilter(CurrTransLine.Number, '=%1|=%2|=%3|=%4|=%5', 'A8545', 'A8546', 'A8547', 'A8548', 'A107882');
        if CurrTransLine.FindSet() then begin
            CurrTransLine.SetRange(CurrTransLine.Number);
            if CurrTransLine.Count > 1 then begin
                Msg := Msg01;
                exit(true);
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', false, false)]
    local procedure OnBeforeTotalExecuted(var POSTransaction: Record "LSC POS Transaction"; var IsHandled: Boolean);
    var
        Text01: Text;
    begin
        if not IsHandled then begin
            if ValidateTopUpTotal(POSTransaction, Text01) then begin
                Message(Text01);
                IsHandled := true;
            end;
        end;
    end;
}