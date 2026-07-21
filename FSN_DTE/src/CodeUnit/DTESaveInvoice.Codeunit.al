codeunit 50038 "FSN DTE Regist"
{
    SingleInstance = true;
    trigger OnRun()
    begin

    end;

    var
        myInt: Integer;
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
        jObject, Resp : JsonObject;
        jToken: JsonToken;
        dteTransaction: Record "FSN DTE Transaction Header";
        transaction: Record "LSC Transaction Header";
        ELectronicInvoice: Codeunit "FSN Electronic Invoice";

    [ServiceEnabled]
    procedure GetResponse(var Response: Text): Boolean
    var
        myInt: Integer;
        Sala, Terminal : Text[20];
        TransNo: Integer;
        xmlFinal: File;
        xmlStream: OutStream;
        JsonFinal: File;
        JsonStream: OutStream;
        TerminalTable: Record "LSC POS Terminal";
    begin
        if Response = '' then
            exit(false);

        TerminalTable.Reset();

        if jObject.ReadFrom(Response) then;

        if jObject.SelectToken('IdShop', jToken) and not (JToken.AsValue().IsNull) then
            Sala := jToken.AsValue().AsText();

        if jObject.SelectToken('TransNo', jToken) and not (JToken.AsValue().IsNull) then
            TransNo := jToken.AsValue().AsInteger();

        if jObject.SelectToken('SellingPoint', jToken) and not (JToken.AsValue().IsNull) then
            Terminal := generateTerminalNo(jToken.AsValue().AsText());

        transaction.Reset();
        transaction.SetRange("Transaction No.", TransNo);
        transaction.SetRange("Store No.", Sala);
        transaction.SetRange("POS Terminal No.", Terminal);
        if transaction.FindFirst() then begin
            if dteTransaction.Get(transaction."Store No.", transaction."POS Terminal No.", transaction."Transaction No.") then begin
                if jObject.SelectToken('SelloRecepcion', jtoken) and not (JToken.AsValue().IsNull) then
                    if (JToken.AsValue().AsText() <> '') then begin
                        if dteTransaction."Signature Validation" = jtoken.AsValue().AsText() then
                            exit(true);
                    end;
            end;
        end
        else
            exit(false);

        if jObject.SelectToken('AuthNumber', jToken) and not (JToken.AsValue().IsNull) then
            dteTransaction."DTE AuthNumber" := jToken.AsValue().AsText();

        if jObject.SelectToken('IssuedTimeStamp', jToken) and not (JToken.AsValue().IsNull) then
            dteTransaction."DTE IssuedTimeStamp" := CopyStr(jToken.AsValue().AsText(), 1, 19);

        if jObject.SelectToken('EnrolledTimeStamp', jToken) and not (JToken.AsValue().IsNull) then
            dteTransaction."DTE EnrolledTimeStamp" := CopyStr(jToken.AsValue().AsText(), 1, 19);

        if jObject.SelectToken('DTEinvoice', jToken) and not (JToken.AsValue().IsNull) then
            dteTransaction."DTE Invoice" := jToken.AsValue().AsText();

        if jObject.SelectToken('TicketType', jtoken) and not (JToken.AsValue().IsNull) then
            dteTransaction."Document Type" := jToken.AsValue().AsText();

        if jObject.SelectToken('SelloRecepcion', jtoken) and not (JToken.AsValue().IsNull) then
            if (JToken.AsValue().AsText() <> '') then begin
                dteTransaction."Signature Validation" := jtoken.AsValue().AsText();

                if jToken.AsValue().AsText() = '04' then begin

                    sendToRemission(jObject);

                    if jObject.SelectToken('TransNo', jToken) and not (JToken.AsValue().IsNull) then
                        dteTransaction."Store No." := jToken.AsValue().AsText();

                    dteTransaction."POS Terminal No." := '2';

                    dteTransaction."Transaction No." := 0;
                end else begin
                    if jObject.SelectToken('IdShop', jToken) and not (JToken.AsValue().IsNull) then
                        dteTransaction."Store No." := jToken.AsValue().AsText();

                    if jObject.SelectToken('TransNo', jToken) and not (JToken.AsValue().IsNull) then
                        dteTransaction."Transaction No." := jToken.AsValue().AsInteger();

                    dteTransaction."POS Terminal No." := transaction."POS Terminal No.";
                end;

                if jObject.SelectToken('GenerationDate', jToken) then
                    dteTransaction."Creating Date" := jToken.AsValue().AsDate();

                if jObject.SelectToken('Secuencial', jToken) then
                    changeSequential(transaction, jToken.AsValue().AsText());

                if not dteTransaction.Insert(true) then
                    dteTransaction.Modify(true);
                exit(true);
            end;
        onAfterSaveInvoice(transaction, dteTransaction);
    end;

    [Normal]
    local procedure sendToRemission(jObject: JsonObject)
    var
        req, res, ID, result : Text;
        jToken: JsonToken;
        processed: Boolean;
        menuline: Record "LSC POS Menu Line";
        fsnUtility: Codeunit "FSN Utility";
        remision: Record "FSN Remission Header";
    begin
        if not jObject.SelectToken('TransNo', jToken) then
            exit;
        if not remision.Get(remision."Document Type"::Remission, jToken.AsValue().AsText()) then
            exit;

        if jObject.SelectToken('DTEinvoice', jToken) then begin
            remision."External Document No." := jToken.AsValue().AsText();
            remision.Modify();
        end;
    end;

    local procedure changeSequential(var transaction: Record "LSC Transaction Header"; seq: Text)
    begin
        transaction."Legal Number" := seq;
        transaction."FSN NCF" := seq;
        transaction."FSN Correlative" := seq;

        if transaction.Modify(true) then;
    end;

    local procedure generateTerminalNo(terminal: Text[20]): Text[20]
    var
        prefix: Label 'PV';
    begin
        terminal := CopyStr(terminal, 3); // Remove the first two characters
        exit(prefix + '#' + terminal);
    end;

    // If the input terminal is 'PV001', the output will be 'PV#001'.

    [IntegrationEvent(false, false)]
    [Scope('OnPrem')]
    local procedure onAfterSaveInvoice(var transaction: Record "LSC Transaction Header"; var DTETransaction: Record "FSN DTE Transaction Header")
    begin
    end;

}