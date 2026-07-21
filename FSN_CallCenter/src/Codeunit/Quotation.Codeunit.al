codeunit 50015 "FSN Quotation"
{

    trigger OnRun()
    begin
    end;

    var
        GlobalRec: Record "LSC POS Menu Line";

    procedure SetMenuLine(pPosMenuLine: Record "LSC POS Menu Line")
    begin
        GlobalRec := pPosMenuLine;
    end;

    procedure SendQuotation(ProcessInput: Boolean; pInput: Text[250])
    var
        Mail: Codeunit "Mail";
        Addressee: list of [Text];
        KeyboardResult: Action;
        FilePath: Text;
        ToFile: Text;
        FileManagement: Codeunit "File Management";
        Quotation: Report "FSN Quotation";
        POSTransaction_l: Record "LSC POS Transaction";
        Caption: Text[50];
        OldValue: Text[100];
        Result: Action;
        ShowLookupButton: Boolean;
        SMTPMailSetup: Record "SMTP Mail Setup";
        SMTP: Codeunit "SMTP Mail";
        lText001: Label 'Send quotation?';
        lText002: Label 'Send to (mail): ';
        lText003: Label 'Cant create report';
        lText004: Label 'Sent sucessffull!';
        lText005: Label 'Cant Send. ';
        lText006: Label 'Message create automatic. Unanswered.';
        lText007: Label 'Quotation.';
        Subject: Text[100];
        OrderOld: Code[20];
        POSSESSION: Codeunit "LSC POS Session";
        POSGUI: Codeunit "LSC POS GUI";
        CC: list of [Text];
    begin
        CLEAR(Mail);

        if not ProcessInput then begin
            IF NOT Confirm(lText001, FALSE) THEN
                EXIT;
            POSGUI.OpenAlphabeticKeyboard('Correo', '', false, 'QUOTATION', 250);
            exit;
        end;
        OrderOld := POSSESSION.GetValue('CURRORDER');
        IF OrderOld = '' THEN
            OrderOld := GlobalRec."Current-RECEIPT";

        POSTransaction_l.RESET;
        POSTransaction_l.SETRANGE(POSTransaction_l."Receipt No.", OrderOld);
        IF NOT POSTransaction_l.FIND('-') THEN
            EXIT;
        Addressee.Add(pInput);
        IF pInput = '' THEN
            EXIT;

        FilePath := 'C:\Cotizaciones\' + OrderOld + '.pdf';

        IF FileManagement.ServerFileExists(FilePath) THEN
            FileManagement.DeleteServerFile(FilePath);

        CLEAR(Quotation);
        POSTransaction_l.RESET;
        POSTransaction_l.SETRANGE(POSTransaction_l."Receipt No.", OrderOld);
        Quotation.SETTABLEVIEW(POSTransaction_l);
        IF NOT Quotation.SAVEASPDF(FilePath) THEN
            ERROR(lText003)
        ELSE BEGIN
            ToFile := FileManagement.DownloadTempFile(FilePath);
            CLEAR(SMTP);
            Subject := lText007 + ' No.' + OrderOld;

            SMTPMailSetup.GET;
            SMTPMailSetup."User ID" := 'app@sannicolas.com.sv';
            SMTP.CreateMessage('Farmacias San Nicolas', SMTPMailSetup."User ID", Addressee, Subject, lText006, TRUE);
            SMTP.AddAttachment(FilePath, 'eMail.pdf');
            CC.Add('consultas@sannicolas.com.sv');
            SMTP.AddCC(CC);
            SMTP.Send();
            Message(lText004);
            EXIT;
        END;
    end;

    procedure SendPaqueteria(Enlace: Text; OrderOld: Code[20]; FilePath: Text; recolecta: Text)
    var
        myInt: Integer;

        SMTPMailSetup: Record "SMTP Mail Setup";
        SMTP: Codeunit "SMTP Mail";
        CC: list of [Text];
        Addressee: list of [Text];
        Subject: Text;
        lText007: Label 'Paqueteria C807 para restaurante: %1 Fecha %2';
        ResponsCC: Record "Responsibility Center";
        DelOrder: Record "LSC Delivery Order";
        CorreoSala: Text;
        FileManagement: Codeunit "File Management";
        Encabezado: Text;
        Mensaje: Text;
        Mes: Label 'CLIENTE: %1, TELEFON: %2, RECOLECTA: %3, Enlace de segimiento: %4';
        TypeHelp: Codeunit "Type Helper";
        InputTime: Time;
        Hour: Integer;
        Minute: Integer;
        Second: Integer;
        Dia: date;
    begin
        if DelOrder.Get(OrderOld) then
            if ResponsCC.Get(DelOrder."Restaurant No.") then
                CorreoSala := ResponsCC."E-Mail";
        Addressee.Add('callcenter@sannicolas.com.sv');
        /* InputTime := Time;
         TypeHelp.GetHMSFromTime(Hour, Minute, Second, InputTime);
         if Hour >= 14 then begin
             Dia := CalcDate('<+1D>', Today);
             Encabezado := StrSubstNo(lText007, DelOrder."Restaurant No.", Dia);
         end else*/
        Encabezado := StrSubstNo(lText007, DelOrder."Restaurant No.", Today);
        Mensaje:= 'Cliente: '+DelOrder.Name;
        Mensaje+= '<p>Telefono: '+DelOrder."Phone No."+'</p>';
        Mensaje+= '<p>Recolecta: '+recolecta+'</p>';
        Mensaje+= '<p>Enlace de seguimiento: '+Enlace+'</p>';

        SMTPMailSetup.GET;
        SMTPMailSetup."User ID" := 'app@sannicolas.com.sv';
        SMTP.CreateMessage('Farmacias San Nicolas', SMTPMailSetup."User ID", Addressee, Encabezado, Mensaje, true);
        SMTP.AddAttachment(FilePath, 'GUIA.pdf');
        CC.Add(CorreoSala);
        SMTP.AddCC(CC);
        SMTP.Send();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnKeyboardResult', '', true, true)]
    local procedure "EPOS Controler_OnKeyboardResult"
    (
        payload: Text;
        inputValue: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    begin
        if payload = 'QUOTATION' then begin
            processed := true;

            SendQuotation(true, inputValue);
        end;
    end;

}