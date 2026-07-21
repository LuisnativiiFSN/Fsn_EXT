codeunit 50052 "FSN Pos Card BAC"
{
    SingleInstance = true;
    trigger OnRun()
    var
    begin
    end;

    var
        Mensaj: Text;
        BOUTIL: Codeunit "LSC BO Utils";
        BINList: Record "FSN BIN Bank";
        AnVouc: Text;

    [ServiceEnabled]
    procedure GetReceip(var Resp: code[20]): Text
    var
        line: Integer;
    begin
        if Resp <> '' then begin
            line := ValTransaccion(Resp);
            if line <> 0 then begin
                if VoidTransaction(Resp, line) <> '' then begin
                    exit(AnVouc);
                end else
                    exit(DataBac(Resp, line))
            end else
                exit('{}')
        end;
    end;

    [ServiceEnabled]
    procedure ResPBac(RespB: Text): Text
    var
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
        RecordNew: Record "FSN POS Card Request Entry";
        PosCard: Record "LSC POS Card Entry";
        document: DotNet XmlDocument;
        Convert: DotNet JsonConvert;
        JObject: DotNet JObject;
        NewJsonTxt: Text;
        ODATACnn: Codeunit "FSN OData Conexion";
        PointsTxt: Text[250];
        PointsDecimal: Decimal;
        PointsBalance: Decimal;
        Recibo: Code[20];
        Prueba: Text;
        Nline: Integer;
        xnodelist: DotNet XmlNodeList;
        xNode: Dotnet XmlNode;
        ResBac: Text;
        OK: Boolean;
        VoidNum: Integer;
        ResOK: Label 'Transaccion Registrada';
        Parameter: Record "FSN Parameter";
    begin
        sb := sb.StringBuilder();
        sb.Append(RespB);
        if xmlFinal.Create('C:\Temp\decryptbac.xml') then begin
            xmlFinal.CreateOutStream(xmlStream);
            xmlStream.Write(sb.ToString);
            xmlFinal.Close();
        end;
        if RespB <> '' then begin
            JObject := JObject.Parse(RespB);
            Evaluate(Nline, ODATACnn.GetValueAsText(JObject, 'LineN'));
            VoidNum := ODATACnn.GetValueAsInteger(JObject, 'VoidNum');
            if VoidNum = 0 then begin
                RecordNew.RESET;
                RecordNew.SETRANGE(RecordNew."Receipt No.", ODATACnn.GetValueAsText(JObject, 'Receip'));
                RecordNew.SetRange(RecordNew."Line No.", Nline);
                IF RecordNew.FindLast() THEN BEGIN
                    ResBac := Format(JObject.SelectToken('BacResponse'));
                    JObject := JObject.SelectToken('BacResponse');
                    document := document.XmlDocument();
                    document.LoadXml(ResBac);
                    NewJsonTxt := Convert.SerializeXmlNode(document);
                    JObject := JObject.Parse(NewJsonTxt);
                    JObject := JObject.SelectToken('EMVStreamResponse');
                    RecordNew."Authorization Code" := ODATACnn.GetValueAsText(JObject, 'responseCode');
                    RecordNew."Trans Authorization" := ODATACnn.GetValueAsText(JObject, 'authorizationNumber');
                    RecordNew."Trans Time" := ODATACnn.GetValueAsText(JObject, 'hostTime');
                    RecordNew."Trans Date" := ODATACnn.GetValueAsText(JObject, 'hostDate');
                    RecordNew.Invoice := ODATACnn.GetValueAsText(JObject, 'invoice');
                    RecordNew."Trans Reference" := ODATACnn.GetValueAsText(JObject, 'referenceNumber');
                    IF RecordNew.Command = 'MANCOMPRAMIL' THEN BEGIN
                        RecordNew."Amount Input" := RecordNew."Enter Input";
                        RecordNew.Points := ODATACnn.GetValueAsText(JObject, 'salesAmount');
                    END ELSE
                        RecordNew."Amount Input" := ODATACnn.GetValueAsText(JObject, 'salesAmount');
                    RecordNew."Trans Audit No" := ODATACnn.GetValueAsText(JObject, 'systemTraceNumber');
                    RecordNew."Trans Tipo Mssg" := ODATACnn.GetValueAsText(JObject, 'transactionId');
                    RecordNew."Entry Mode" := ODATACnn.GetValueAsText(JObject, 'entryMode');
                    IF NOT (RecordNew.Command = 'MANCONMILLA') THEN BEGIN
                        RecordNew."Response Web Ok" := RecordNew."Authorization Code" = '00';
                    END ELSE BEGIN
                        IF RecordNew."Authorization Code" = '00' THEN BEGIN
                            RecordNew."Response Web Ok" := FALSE;
                            RecordNew."Authorization Code" := 'OK';
                            PointsTxt := RecordNew."Amount Input";
                            IF PointsTxt = '' THEN
                                PointsTxt := '0';
                            CLEAR(PointsDecimal);
                            IF EVALUATE(PointsDecimal, PointsTxt) THEN;
                            RecordNew."Amount Input" := FORMAT(ROUND(PointsDecimal * 0.006, 1));
                            RecordNew.Points := FORMAT(ROUND(PointsDecimal, 1));
                        END;
                    END;
                    if Parameter.Get('SAVE', 'AUTORIZATION') and Parameter.Activo then
                        if (RecordNew."Authorization Code" = '00') and (RecordNew."Trans Authorization" = '') then begin
                            RecordNew."Amount Input" := RecordNew."Enter Input";
                            RecordNew."Trans Authorization" := RecordNew."Receipt ID";
                        end;

                    RecordNew."Retailer ID" := 'CDSN0004';
                    RecordNew."Terminal ID" := 'CDSN0004';
                    RecordNew."Entity Name" := 'CREDOMATIC';
                    RecordNew.MODIFY(TRUE);
                    if RecordNew."Response Web Ok" THEN begin
                        PosCard.Reset();
                        PosCard.SetRange("Receipt No.", RecordNew."Receipt No.");
                        PosCard.SetRange("Line No.", RecordNew."Line No.");
                        if PosCard.Find('-') then begin
                            TransferInfoToCardEntry(RecordNew, PosCard);
                        end;
                    end;
                end;
            END else begin
                RecordNew.RESET;
                RecordNew.SETRANGE(RecordNew."Receipt No.", ODATACnn.GetValueAsText(JObject, 'Receip'));
                RecordNew.SetRange(RecordNew."Void Number", VoidNum);
                IF RecordNew.FIND('-') THEN BEGIN
                    ResBac := Format(JObject.SelectToken('BacResponse'));
                    JObject := JObject.SelectToken('BacResponse');
                    document := document.XmlDocument();
                    document.LoadXml(ResBac);
                    NewJsonTxt := Convert.SerializeXmlNode(document);
                    JObject := JObject.Parse(NewJsonTxt);
                    JObject := JObject.SelectToken('EMVStreamResponse');
                    RecordNew."Authorization Code" := ODATACnn.GetValueAsText(JObject, 'responseCode');
                    RecordNew."Trans Authorization" := ODATACnn.GetValueAsText(JObject, 'authorizationNumber');
                    RecordNew."Trans Time" := ODATACnn.GetValueAsText(JObject, 'hostTime');
                    RecordNew."Trans Date" := ODATACnn.GetValueAsText(JObject, 'hostDate');
                    RecordNew."Trans Reference" := ODATACnn.GetValueAsText(JObject, 'referenceNumber');
                    RecordNew."Response Web Ok" := RecordNew."Authorization Code" = '00';
                    RecordNew."Retailer ID" := 'CDSN0004';
                    RecordNew."Terminal ID" := 'CDSN0004';
                    RecordNew."Entity Name" := 'CREDOMATIC';
                    RecordNew.Modify();
                end;
            end;
            exit(ResOK);
        end else
            exit('{}');
    end;

    [ServiceEnabled]
    procedure DataBac(var Reci: Code[20]; line: Integer): Text
    var
        json: JsonObject;
        staff: JsonObject;
        jValue: JsonValue;
        PosCardEntry: Record "LSC POS Card Entry";
        PosCardReq: Record "FSN POS Card Request Entry";
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        PosCardReq.Reset();
        PosCardReq.SetRange("Receipt No.", Reci);
        PosCardReq.SetRange("Line No.", line);
        PosCardReq.SetRange("Response Web Ok", false);
        if PosCardReq.FindLast() then begin
            PosCardEntry.Reset();
            PosCardEntry.SetRange("Receipt No.", Reci);
            PosCardEntry.SetRange("Line No.", PosCardReq."Line No.");
            PosCardEntry.SetRange("Authorisation Ok", false);
            if PosCardEntry.Find('-') then begin
                json.Add('Receip', PosCardEntry."Receipt No.");
                json.Add('ReceipID', PosCardReq."Receipt ID");
                json.Add('LineN', PosCardEntry."Line No.");
                json.Add('CardNum', Decrypt(PosCardEntry."EFT Additional ID"));
                if PosCardEntry."FSN Bank Name" <> '' then
                    json.Add('NameBank', PosCardEntry."FSN Bank Name")
                else
                    json.Add('NameBank', '');
                json.Add('DUI', Client(PosCardReq."Customer No."));
                json.Add('BIN', PosCardEntry."FSN BIN No.");
                json.add('Type', PosCardReq.Command);
                if PosCardReq.Command = 'MANCOMPRAPLA' then
                    json.Add('Plazo', PosCardReq.Plazo)
                else
                    json.Add('Plazo', '');
                json.Add('LastDate', PosCardEntry."Expiry Date");
                if PosCardReq.Command <> 'MANCONMILLA' then
                    json.Add('Amount', PosCardEntry.Amount)
                else
                    json.Add('Amount', '');
                json.Add('Terminal', 'CDSN0004');
                json.WriteTo(Mensaj);
                exit(Mensaj)
            end;
        end;
    end;

    [Normal]
    procedure ValTransaccion(rec: Code[20]): Integer
    var
        PosTransLine: Record "LSC POS Trans. Line";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        PCardRequEntry: Record "FSN POS Card Request Entry";
        PCardEntry: Record "LSC POS Card Entry";
    begin
        POSTransLine.Reset();
        POSTransLine.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        POSTransLine.SetRange("Receipt No.", rec);
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::Payment);
        POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
        if POSTransLine.Find('-') then begin
            repeat
                if TenderTypeSetup.Get(POSTransLine.Number) and (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card) then begin
                    PCardEntry.Reset();
                    PCardEntry.SetRange("Receipt No.", PosTransLine."Receipt No.");
                    PCardEntry.SetRange("Line No.", PosTransLine."Line No.");
                    if PCardEntry.Find('-') then begin
                        repeat
                            if (PCardEntry."Res.code" <> '00') and (PCardEntry."EFT Device Name" <> 'WOMPI') then begin
                                exit(PCardEntry."Line No.");
                            end;
                        until PCardEntry.Next() = 0;
                    end;
                end;
            until PosTransLine.Next() = 0;
        end else begin
            PCardRequEntry.Reset();
            PCardRequEntry.SetRange("Receipt No.", rec);
            PCardRequEntry.SetRange("Response Web Ok", false);
            PCardRequEntry.SetFilter(PCardRequEntry."Void Number", '<>%1', 0);
            if PCardRequEntry.FindFirst() then begin
                exit(PCardRequEntry."Line No.");
            end;
            exit(0);
        end;
    end;

    [Normal]
    procedure VoidTransaction(Rec: Code[20]; line: Integer): Text
    var
        myInt: Integer;
        Rpostr: Record "FSN POS Card Request Entry";
        json: JsonObject;
        staff: JsonObject;
        jValue: JsonValue;
    begin
        Rpostr.SetRange("Receipt No.", rec);
        Rpostr.SetRange("Authorization Code", '00');
        Rpostr.SetRange("Line No.", line);
        if Rpostr.Find('-') then begin
            json.Add('authorizationNumber', Rpostr."Trans Authorization");
            json.Add('referenceNumber', Rpostr."Trans Reference");
            json.Add('systemTraceNumber', Rpostr."Trans Audit No");
            json.Add('transactionId', Rpostr."Trans Tipo Mssg");
            json.Add('Terminal', 'CDSN0004');
            json.Add('VoidNum', Rpostr."Entry No.");
            json.Add('Receip', Rpostr."Receipt No.");
            json.Add('NameBank', Rpostr."Bank Name");
            json.Add('BIN', Rpostr.BIN);
            json.WriteTo(AnVouc);
            exit(AnVouc)
        end else
            exit('');
    end;

    [Normal]
    procedure Client(CodCl: Code[20]): Text
    var
        myInt: Integer;
        Cust: Record Customer;
    begin
        Cust.SetRange("No.", CodCl);
        if Cust.Find('-') then
            exit(Cust."FSN DUI")
    end;

    [Normal]
    procedure TransferInfoToCardEntry(pFromCardRequestEntry: Record "FSN POS Card Request Entry"; pToCardEntry: Record "LSC POS Card Entry")
    var
        pKey: Text;
    begin
        pToCardEntry.Get(pToCardEntry."Store No.", pToCardEntry."POS Terminal No.", pToCardEntry."Entry No.");
        UpdatePOSCardEntryAuthorization(pToCardEntry, pFromCardRequestEntry);
        UpdatePOSCardEntryByBIN(pToCardEntry, pFromCardRequestEntry.BIN);
        pToCardEntry.Modify(TRUE);
    end;

    [Normal]
    procedure UpdatePOSCardEntryAuthorization(var pPosCardEntry: Record "LSC POS Card Entry"; pRequEntry: Record "FSN POS Card Request Entry")
    var
        pKey: Text;
    begin
        pPosCardEntry."Auth.code" := pRequEntry."Trans Authorization";
        pPosCardEntry."EFT Trans. Date" := pRequEntry."Trans Date";
        pPosCardEntry."EFT Trans. Time" := pRequEntry."Trans Time";
        pPosCardEntry."EFT Trans. No." := pRequEntry."Trans Reference";
        pPosCardEntry."EFT Merchant No." := pRequEntry."Retailer ID";
        pPosCardEntry."EFT Terminal ID" := CopyStr(pRequEntry."Terminal ID", 1, 10);
        pPosCardEntry."Res.code" := pRequEntry."Authorization Code";
        pPosCardEntry."Authorisation Ok" := pPosCardEntry."Res.code" = '00';
        if CopyStr(pRequEntry.Command, 1, 3) = 'MAN' then
            pPosCardEntry."Auth. Source Code" := 'PREPAYMENT'
        else
            pPosCardEntry."Auth. Source Code" := 'KINPOS';
        pPosCardEntry."Expiry Date" := pRequEntry."Card Last Date";
        pPosCardEntry."FSN CVV" := pRequEntry.CVV;
        pPosCardEntry.Date := Today;
        pPosCardEntry.Time := Time;
        pPosCardEntry."Extra Data" := 'ATH';
        pKey := BOUTIL.CombineValue(5, FORMAT(pRequEntry."Entry No."), FORMAT(DATE2DMY(pRequEntry."Date Key", 1))
                             , FORMAT(DATE2DMY(pRequEntry."Date Key", 2))
                             , FORMAT(DATE2DMY(pRequEntry."Date Key", 3)), pRequEntry."Distribution Location");
        pPosCardEntry."FSN Operation Name" := COPYSTR(pKey, 1, 50);
        pPosCardEntry."FSN Print Amount" := pPosCardEntry.Amount;

        if pRequEntry.Plazo <> '' then
            pPosCardEntry."FSN Points/Terms" := pRequEntry.Plazo;
        if pRequEntry.Points <> '' then
            pPosCardEntry."FSN Points/Terms" := pRequEntry.Points;
    end;

    [Normal]
    procedure UpdatePOSCardEntryByBIN(var pPosCardEntry: Record "LSC POS Card Entry"; pBin: Code[10])
    begin
        IF NOT BINList.GET(pBIN) THEN BEGIN
            BINList.INIT();
            CLEAR(BINList);
            BINList."BIN/IIN" := pBIN;
        END;
        pPosCardEntry."Card Type" := BINList."Card Type";
        pPosCardEntry."Card Type Name" := BINList."Scheme Text";
        pPosCardEntry."Extra Data" := BINList."Extra Data";
        pPosCardEntry."FSN BIN No." := pBIN;
        if BINList."Bank Name" <> '' then
            pPosCardEntry."FSN Bank Name" := BINList."Bank Name";
    end;
}