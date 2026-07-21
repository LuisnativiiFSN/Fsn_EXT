codeunit 50010 "FSN_Web_Request"
{
    /*trigger OnRun()
    var
        WSRequest_l: Record "LSC POS Func. Profile Web Req.";
        func: codeunit "LSC POS Transaction";
        FUNT: Codeunit "LSC POS Functions";
    begin
        WSRequest_l.Reset();
        WSRequest_l.SetRange("Profile ID");

        if WSRequest_l.Find('+') then
            Message('ok');

        //Recorrer un registro
        WSRequest_l.Reset();
        WSRequest_l.SetRange("Profile ID", '');
        if WSRequest_l.Find('-') then begin
            Message('Si hay registros');

            repeat //bucle

                Message('Proceso');

            until WSRequest_l.next() = 0; //ascendente cuando Find('-')
            //until WSRequestl.next(-1) = 0; //ascendente cuando Find('+')
        end;

        WSRequest_l.Reset();
        Clear(WSRequest_l);

        WSRequest_l.Init();
        WSRequest_l."Profile ID" := '#FASANI';
        WSRequest_l."Request ID" := 'FSN_GET_INVENTORY';
        WSRequest_l."Request is Active" := true;
        WSRequest_l.Insert();

        
    end;*/

    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterTenderKeyPressedEx', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterTenderKeyPressedEx"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var TenderTypeCode: Code[10];
        var TenderAmountText: Text;
        var IsHandled: Boolean
    )
    var
        SQL: Codeunit "FSN SQL Data Reader";
        FSNParameter: Record "FSN Parameter";
        Reader: DotNet SqlDataReader;
        CustomerServer: Record Customer;
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
        Dec: Decimal;
        CBalanceOverLimit: Decimal;
        lTxt1: Label 'Query cust balance not exists. %1';
        lTxt2: Label 'Customer balance is not enough. %1';
        lTxt3: Label 'Error conection to distribution code %1';
        query1: Text;
    begin
        if not TenderTypeSetup_l.Get(TenderTypeCode) then
            exit;
        if not (TenderTypeSetup_l."Default Function" = TenderTypeSetup_l."Default Function"::Customer) then
            exit;

        if not FSNParameter.Get('POS', 'WSGETCUST') then begin
            Message(StrSubstNo(lTxt1, FSNParameter.TableCaption));
            IsHandled := true;
            exit;
        end;
        FSNParameter.TestField("Distribution Location Ext.");
        query1 := 'EXEC BcentralGetBalanceCustomer ''' + POSTransaction."Customer No." + '''';

        SQL.ClearParams();
        SQL.SetDistributionLocation(FSNParameter."Distribution Location Ext.");
        SQL.SetQuery(query1);
        SQL.SetAction('OPEN');
        IF SQL.Run() THEN;
        IF not SQL.IsConnect() THEN begin
            Message(StrSubstNo(lTxt3, FSNParameter."Distribution Location Ext."));
            IsHandled := true;
            exit;
        end;
        SQL.SetAction('POST');
        if not SQL.Run() then begin
            SQL.SetAction('CLOSE');
            IF SQL.Run() then;
            Message(StrSubstNo(lTxt3, FSNParameter."Distribution Location Ext."));
            IsHandled := true;
            exit;
        end;
        SQL.GetDataReader(Reader);
        Clear(CustomerServer);
        CustomerServer."Balance (LCY)" := Reader.Item('Amount');
        CustomerServer."LSC Amt. Charged On POS" := Reader.Item('AmountToAccount');
        CustomerServer."LSC Amt. Charged Posted" := Reader.Item('Amount2Account');

        SQL.SetAction('CLOSE');
        if SQL.Run() then;

        Clear(Dec);
        Clear(TenderAmountText);
        if CurrInput <> '' then begin
            if Evaluate(Dec, CurrInput) then;
        end else
            if Evaluate(Dec, TenderAmountText) then;

        CBalanceOverLimit := (CustomerServer."Balance (LCY)" + CustomerServer."LSC Amt. Charged On POS" - CustomerServer."LSC Amt. Charged Posted" + Dec) - CustomerServer."Credit Limit (LCY)";
        if CBalanceOverLimit > 0 then begin
            CBalanceOverLimit := (CustomerServer."Balance (LCY)" + CustomerServer."LSC Amt. Charged On POS" - CustomerServer."LSC Amt. Charged Posted" + Dec) - CustomerServer."Credit Limit (LCY)";
            Message(StrSubstNo(lTxt2, Format(CBalanceOverLimit)));
            IsHandled := true;
            exit;
        end;
    end;*///DA ERROR

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        POSTransactionCodeunit: Codeunit "LSC POS Transaction";
        POSSession: Codeunit "LSC POS Session";
        POSLine: Record "LSC POS Trans. Line";
        Staff: Record "LSC Staff";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        if (POSSession.GetValue('FSNLASTRCPTSSTAFF') <> POSTransaction."Receipt No.") or (POSTransaction."Sales Staff" = '') then begin
            POSSession.SetValue('FSNLASTRCPTSSTAFF', POSTransaction."Receipt No.");

            POSLine.Reset();
            POSLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
            POSLine.SetRange("Entry Status", POSLine."Entry Status"::" ");
            POSLine.SetRange("Entry Type", POSLine."Entry Type"::Item);

            RequestID := 'FSNCC';
            Processed := false;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            IF NOT Processed THEN BEGIN
                if (POSTransaction."Sales Staff" = '') then begin
                    CurrInput := '';
                    POSTransactionCodeunit.ProcessSalesPerson();
                    exit;
                end else
                    if Staff.Get(POSTransaction."Sales Staff") then
                        if (Staff."Permission Group" <> 'WAITERS') and not POSLine.Find('-') then begin
                            CurrInput := '';
                            POSTransactionCodeunit.ProcessSalesPerson();
                            exit;
                        end;
            END
        end;



    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeSetFunctionModeSalesPressed', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeSetFunctionModeSalesPressed"
    (
        POSFuncProfile: Record "LSC POS Func. Profile";
        POSTransaction: Record "LSC POS Transaction";
        Keyed: Boolean;
        var CurrInput: Text;
        var IsHandled: Boolean
    )
    VAR
        POSSession: Codeunit "LSC POS Session";
    begin

        POSSession.SetValue('FSNLASTRCPTSSTAFF', POSTransaction."Receipt No.");
    end;


}





