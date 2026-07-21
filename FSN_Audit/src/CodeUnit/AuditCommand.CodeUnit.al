/// <summary>
/// Codeunit FSN Audit Command (ID 50048).
/// </summary>
codeunit 50048 "FSN Audit Command"
{
    TableNo = 99008906; //LSC POS Menu Line
    trigger OnRun()
    begin
        gCommand := Rec.Command;
        if not gPOSTrans.Get(Rec."Current-RECEIPT") then
            Error(StrSubstNo(gText001, Rec."Current-RECEIPT"));

        case
            gCommand of
            'COMANDAUDITORIA':
                ValidateSalesTypeAudit(gPOSTrans);
        end;
    end;
    #region [Variables Globales]
    var
        gPOSTrans: Record "LSC POS Transaction";
        Staff: Record "LSC Staff";
        POSCtrlInterface: Codeunit "LSC POS Control Interface";
        POSGUI: Codeunit "LSC POS GUI";
        POSSesion: Codeunit "LSC POS Session";
        POSTransCode: Codeunit "LSC POS Transaction";
        gCommand: Code[20];
        gText001: label 'Transaction No: %1 Not Found';

    #endregion
    #region [Procedimientos Locales]
    local procedure ValidateSalesTypeAudit(POSTrans: Record "LSC POS Transaction")
    var
        ComissionSales: Record "LSC Cmsn Salesp. Grp Member";
        POSIntfProfile: Record "LSC POS Interface Profile";
        OK: Boolean;
        lWorkShift: Code[1];
        lStaffID: Code[20];
        lText001: Label 'User not Exists in Seller Group "Audit"';
        lText002: Label 'Next Transaction is marked to Audit';
        lPassword: Text;
        lReasonText: Text;
    begin
        if POSSesion.ManagerID() = '' then begin
            POSSesion.SetValue('CodeUnitID', '50048');
            POSCtrlInterface.ShowPanelModal('#FSNLOGIN', 'COMANDAUDITORIA');
        end else begin
            ComissionSales.Reset();
            ComissionSales.SetCurrentKey("Group Code", "No.");
            ComissionSales.SetRange("Group Code", 'AUDITORIA');
            ComissionSales.SetRange("No.", POSSesion.ManagerID());
            if not ComissionSales.FindFirst() then begin
                Error(lText001);
                exit;
            end;

            if POSTrans."Sales Type" = 'AUDITORIA' then begin
                POSGUI.PosMessage(lText002);
                exit;
            end;

            POSTransCode.ChangeSalesType('AUDITORIA', 'SETSALESTYPE_TRANS');

            if POSTrans.Get(POSTransCode.GetReceiptNo()) then
                if (POSTrans."Sales Type" = 'AUDITORIA') then begin
                    POSGUI.PosMessage(lText002);
                    exit;
                end;
        end;
    end;

    local procedure VerifyStaff(payload: Text; ResultOK: Boolean; var Processed: Boolean)
    var
        MenuLine: Record "LSC POS Menu Line";
        perGroup: Record "LSC STAFF PER Group";
        CodeUnitID: Integer;
        lText001: Label 'This User is not manager';
        Pass: Text;
        pReasonText: Text;
        StaffID: Text;
        workshift: Text;
    begin
        if ResultOK then begin
            Processed := true;
            StaffID := POSCtrlInterface.GetInputText(POSSesion.StaffInputID());
            Pass := POSCtrlInterface.GetInputText(POSSesion.PasswordInputID());
            workshift := CopyStr(POSCtrlInterface.GetInputText(POSSesion.WorkShiftInputID()), 1, 1);

            if (StaffID = '') then
                exit;

            if not POSSesion.Login(true, StaffID, Pass, workshift, pReasonText) then begin
                POSGUI.PosMessage(pReasonText);
                exit;
            end;

            if not Staff.Get(StaffID) then
                exit;

            if perGroup.Get(Staff."Permission Group") then begin
                if perGroup."Manager Privileges" <> perGroup."Manager Privileges"::Yes then begin
                    POSGUI.PosMessage(lText001);
                    exit;
                end;
            end;

            POSSesion.SetManagerID(Staff, pReasonText);
            MenuLine.Init();
            MenuLine.Command := payload;
            MenuLine."Current-RECEIPT" := POSTransCode.GetReceiptNo();
            if Evaluate(CodeUnitID, POSSesion.GetValue('CodeUnitID')) then
                Codeunit.Run(CodeUnitID, MenuLine);
        end;
    end;
    #endregion
    #region [subcripciones]
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnModalPanelResult', '', true, true)]
    local procedure "LSC POS Controller_OnModalPanelResult"
    (
        panelID: Text;
        resultOK: Boolean;
        payload: Text;
        var processed: Boolean
    )
    begin
        if panelID = '#FSNLOGIN' then begin
            VerifyStaff(payload, resultOK, processed);
            exit;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterInsertNewTransaction', '', false, false)]
    local procedure OnAfterInsertNewTransaction(var POSTransaction: Record "LSC POS Transaction"; var POSTransLine: Record "LSC POS Trans. Line"; var CurrInput: Text);
    var
        Terminal: Record "LSC POS Terminal";
        DefaultSalesType: Code[20];
    begin
        if (POStransaction."Sales Type" = 'AUDITORIA') and (POSTransaction."New Transaction") then begin
            if (Terminal.Get(POSSesion.TerminalNo())) and (Terminal."Default Sales Type" <> '') then
                DefaultSalesType := Terminal."Default Sales Type"
            else
                DefaultSalesType := 'POS';
            POSTransCode.ChangeSalesType(DefaultSalesType, 'SETSALESTYPE_TRANS');
        end;
    end;
    #endregion

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Bank Acc. Reconciliation Post", 'OnCloseBankAccLedgEntryOnBeforeBankAccLedgEntryModify', '', true, true)]
    local procedure "Bank Acc. Reconciliation Post_OnCloseBankAccLedgEntryOnBeforeBankAccLedgEntryModify"
    (
        var BankAccountLedgerEntry: Record "Bank Account Ledger Entry";
        BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line"
    )
    var
        Error: Label 'Lineas de estado de cuenta %1 , no corresponde a numero de documento externo %2 en linea %3';
        Error2: Label 'Lineas de estado de cuenta no puede estar vacío ya que no corresponde a numero de documento externo %1 en fecha %2';
        ErrorDE: Label 'Numero de Documento Externo no puede estar vacío';

    begin
        if (BankAccReconciliationLine.Description = '') then
            Error(STRSUBSTNO(Error2, BankAccountLedgerEntry."External Document No.", BankAccountLedgerEntry."Posting Date"));
        /*
        If (BankAccountLedgerEntry."External Document No." = '') then
        Error(ErrorDE);
        */
        if ((BankAccReconciliationLine.Description <> '') and (BankAccountLedgerEntry."External Document No." <> '')) then
            if (BankAccReconciliationLine.Description <> BankAccountLedgerEntry."External Document No.") then
                Error(STRSUBSTNO(Error, BankAccReconciliationLine.Description, BankAccountLedgerEntry."External Document No.", BankAccReconciliationLine."Statement Line No."));
    end;


    /*
            [EventSubscriber(ObjectType::Table, Database::"Bank Acc. Reconciliation Line", 'OnBeforeModifyEvent', '', true, true)]
            local procedure "Bank Acc. Reconciliation Line_OnBeforeModifyEvent"
            (
                var Rec: Record "Bank Acc. Reconciliation Line";
                var xRec: Record "Bank Acc. Reconciliation Line";
                RunTrigger: Boolean
            )
            var
                BankAccLedgEntry: Record "Bank Account Ledger Entry";
                Error: Label 'Lineas de estado de cuenta %1 , no corresponde a numero de documento externo %2 en linea %3';
                Error2: Label 'Lineas de estado de cuenta no puede estar vacío ya que no corresponde a numero de documento externo %1 en fecha %2';
                ErrorDE: Label 'Numero de Documento Externo no puede estar vacío';
                POSSESSION: Codeunit "LSC POS Session";
            begin
                if POSSESSION.GetValue('MANUAL') <> 'TRUE' then begin
                    BankAccLedgEntry.Reset();
                    BankAccLedgEntry.SetCurrentKey("Bank Account No.", Open);
                    BankAccLedgEntry.SetRange("Bank Account No.", Rec."Bank Account No.");
                    BankAccLedgEntry.SetRange(Open, true);
                    BankAccLedgEntry.SetRange("Statement Status", BankAccLedgEntry."Statement Status"::"Bank Acc. Entry Applied");
                    BankAccLedgEntry.SetRange("Statement No.", Rec."Statement No.");
                    BankAccLedgEntry.SetRange("Statement Line No.", Rec."Statement Line No.");
                    if not BankAccLedgEntry.Find('-') then begin
                        if Rec."Applied Entries" = 1 then begin
                            Rec.Difference := Rec."Applied Amount";
                            Rec."Applied Entries" := 0;
                            Rec."Applied Amount" := 0.0;
                            RunTrigger := true;
                        end;
                    end;
                end;
            end;

            [EventSubscriber(ObjectType::Table, Database::"Bank Account Ledger Entry", 'OnBeforeModifyEvent', '', true, true)]
            local procedure "Bank Account Ledger Entry_OnBeforeModifyEvent"
            (
                var Rec: Record "Bank Account Ledger Entry";
                var xRec: Record "Bank Account Ledger Entry";
                RunTrigger: Boolean
            )
            var
                BankAccLine: Record "Bank Acc. Reconciliation Line";
                POSSESSION: Codeunit "LSC POS Session";
            begin
                if POSSESSION.GetValue('MANUAL') <> 'TRUE' then begin
                    BankAccLine.Reset();
                    BankAccLine.SetRange("Statement Type", BankAccLine."Statement Type"::"Bank Reconciliation");
                    BankAccLine.SetRange("Bank Account No.", Rec."Bank Account No.");
                    BankAccLine.SetRange("Statement No.", Rec."Statement No.");
                    BankAccLine.SetRange("Statement Line No.", Rec."Statement Line No.");
                    if BankAccLine.FindFirst() then begin
                        if Rec."Statement Status" = Rec."Statement Status"::"Bank Acc. Entry Applied" then
                            if Rec."External Document No." <> BankAccLine.Description then begin
                                Rec."Statement No." := '';
                                Rec."Statement Line No." := 0;
                                Rec."Statement Status" := Rec."Statement Status"::Open;
                                RunTrigger := true;
                            end;
                    end;
                end;
            end;


            [EventSubscriber(ObjectType::Page, Page::"Bank Acc. Reconciliation", 'OnBeforeActionEvent', 'MatchManually', true, true)]
            local procedure "Bank Acc. Reconciliation_OnBeforeActionEvent_[processing / M&atching] - MatchManually"(var Rec: Record "Bank Acc. Reconciliation")
            var
                POSSESSION: Codeunit "LSC POS Session";
            begin
                POSSESSION.SetValue('MANUAL', 'TRUE');
            end;


            [EventSubscriber(ObjectType::Page, Page::"Bank Acc. Reconciliation", 'OnAfterActionEvent', 'MatchManually', true, true)]
            local procedure "Bank Acc. Reconciliation_OnAfterActionEvent_[processing / M&atching] - MatchManually"(var Rec: Record "Bank Acc. Reconciliation")
            var
                POSSESSION: Codeunit "LSC POS Session";
            begin
                if POSSESSION.GetValue('MANUAL') = 'TRUE' then
                    POSSESSION.SetValue('MANUAL', 'FALSE');
            end;
            */


    [EventSubscriber(ObjectType::Table, Database::"LSC Item Status Link", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC Item Status Link_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC Item Status Link";
        RunTrigger: Boolean
    )
    begin
        //Evita asignar una fecha de inicio al crear el producto. 
        //El sistema valida que, si la fecha es distinta de 0D, se reemplace automáticamente por 0D.
        if Rec."Starting Date" <> 0D THEN
            Rec."Starting Date" := 0D;
    end;

}