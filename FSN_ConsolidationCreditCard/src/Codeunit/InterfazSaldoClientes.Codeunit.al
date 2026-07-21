codeunit 50064 InterfazSaldoClientes
{
    // // Para actualizar los saldos en Interfaz
    // // CSALX20170109 Actualizar el limite de credito en la tabla interfaz


    trigger OnRun()
    begin

        xJrn.Reset();
        xJrn.SetRange("Journal Template Name", 'RECEPCION');
        xJrn.SETRANGE("Journal Batch Name", 'BANK');
        if xJrn.Find('-') then
            repeat
                xJrn.Delete();
            until xJrn.Next() = 0;
        ApplyTransactions;
        ApplyTransactionsDev;
        //VerifyBalance;
        ActualizaSaldos;
    end;

    var
        xJrn: Record "Gen. Journal Line";
        GenJrnlLine: Record "Gen. Journal Line";
        tr: Record "LSC Transaction Header";
        Window: Dialog;
        RefPostingState: Option "Checking lines","Checking balance","Updating bal. lines","Posting Lines","Posting revers. lines","Updating lines";
        CheckingLinesMsg: Label 'Checking lines';
        CheckingBalanceMsg: Label 'Checking balance';
        UpdatingBalLinesMsg: Label 'Updating bal. lines';
        PostingLinesMsg: Label 'Posting lines';
        PostingReversLinesMsg: Label 'Posting revers. lines';
        UpdatingLinesMsg: Label 'Updating lines';

    procedure VerifyBalance()
    var
        xCust: Record "Customer";
        xInter: Record "FSN InterfazCreditos";
        xDIff: Decimal;
        xPostear: Boolean;
        xCle: Record "Cust. Ledger Entry";
        xDcle: Record "Detailed Cust. Ledg. Entry";
        xCorr: Integer;
        xcdet: Integer;
    begin
        // Recorrer la tabla de Interfaces
        xPostear := FALSE;
        // El saldo actual de un cliente es el campo calculado
        // "Balance (LCY)" + "Amt. Charged On POS" - "Amt. Charged Posted"
        // Que toma el saldo (Balance LCY), le suma las transacciones de POS (Amt. Charged On POS),
        // y le resta las transacciones posteadas (que ya forman parte del saldo)
        // Llenar los datos de clientes en tabla de interfaces
        xCust.RESET;
        xCust.SETFILTER("Credit Limit (LCY)", '>%1', 0);
        IF xCust.FIND('-') THEN
            REPEAT
                xCust.CALCFIELDS("Balance (LCY)", "LSC Amt. Charged On POS", "LSC Amt. Charged Posted");
                xInter.RESET;
                xInter.SETRANGE("Customer No.", xCust."No.");
                IF xInter.FIND('-') THEN BEGIN
                    // Comparar el saldo
                    xDIff := xInter.Balance - (xCust."Balance (LCY)" + xCust."LSC Amt. Charged On POS" - xCust."LSC Amt. Charged Posted");
                    IF xDIff <> 0 THEN BEGIN
                        IF (xInter.EBS OR xInter.LDCOM) THEN BEGIN
                            // Obtener el siguiente numero de transaccion
                            CLEAR(xCle);
                            xCle.SETCURRENTKEY("Entry No.");
                            IF xCle.FINDLAST THEN
                                xCorr := xCle."Entry No." + 1
                            ELSE
                                xCorr := 1;

                            // Ajustar en LS
                            // Insertar en Cust Ledger Entry
                            CLEAR(xCle);
                            xCle.INIT;
                            xCle."Entry No." := xCorr;
                            xCle."Posting Date" := WORKDATE;
                            xCle."Due Date" := WORKDATE;
                            xCle."Customer No." := xCust."No.";
                            IF xDIff > 0 THEN BEGIN
                                xCle."Document Type" := xCle."Document Type"::Invoice;
                                xCle.Positive := TRUE;
                            END ELSE BEGIN
                                xCle."Document Type" := xCle."Document Type"::Payment;
                                xCle.Positive := FALSE;
                            END;
                            IF xInter.EBS THEN BEGIN
                                xCle."Document No." := 'TRNEBS';
                                xCle.Description := 'Transaccion EBS';
                            END ELSE BEGIN
                                xCle."Document No." := 'TRNLDCOM';
                                xCle.Description := 'Transaccion LDCOM';
                            END;
                            xCle.INSERT;
                            // Obtener el siguiente correlativo de detalle
                            CLEAR(xDcle);
                            xDcle.SETCURRENTKEY("Entry No.");
                            IF xDcle.FINDLAST THEN
                                xcdet := xDcle."Entry No." + 1
                            ELSE
                                xcdet := 1;

                            // Insertar en Detail Cust. Ledger Entry
                            CLEAR(xDcle);
                            xDcle.INIT;
                            xDcle."Entry No." := xcdet;
                            xDcle."Cust. Ledger Entry No." := xCorr;
                            xDcle."Posting Date" := WORKDATE;
                            xDcle."Initial Entry Due Date" := WORKDATE;
                            xDcle."Entry Type" := xDcle."Entry Type"::"Correction of Remaining Amount";
                            IF xDIff > 0 THEN
                                xDcle."Document Type" := xDcle."Document Type"::Invoice
                            ELSE
                                xDcle."Document Type" := xDcle."Document Type"::Payment;
                            xDcle."Document No." := FORMAT(xCorr);
                            xDcle.Amount := xDIff;
                            xDcle."Amount (LCY)" := xDIff;
                            IF xDIff > 0 THEN BEGIN
                                xDcle."Debit Amount" := ABS(xDIff);
                                xDcle."Debit Amount (LCY)" := ABS(xDIff);
                            END ELSE BEGIN
                                xDcle."Credit Amount" := ABS(xDIff);
                                xDcle."Credit Amount (LCY)" := ABS(xDIff);
                            END;
                            xDcle."Customer No." := xCust."No.";
                            xDcle.INSERT;

                            // Remover bandera de Interfaz
                            xInter.EBS := FALSE;
                            xInter.LDCOM := FALSE;
                            xInter.MODIFY;
                            xPostear := TRUE;
                        END ELSE BEGIN
                            // Ajustar Interfaz
                            xInter.Balance := (xCust."Balance (LCY)" + xCust."LSC Amt. Charged On POS" - xCust."LSC Amt. Charged Posted");
                            xInter.EBS := FALSE;
                            xInter.LDCOM := FALSE;
                            xInter.MODIFY;
                        END;
                    END ELSE BEGIN
                        xInter.EBS := FALSE;
                        xInter.LDCOM := FALSE;
                        xInter.MODIFY;
                    END
                END ELSE BEGIN
                    // Insertar el registro
                    xInter.INIT;
                    xInter."Customer No." := xCust."No.";
                    xInter.ReferenciaEBS := xCust."FSN EBS Reference";
                    xInter."Credit Limit" := xCust."Credit Limit (LCY)";
                    xInter.Balance := (xCust."Balance (LCY)" + xCust."LSC Amt. Charged On POS" - xCust."Lsc Amt. Charged Posted");
                    xInter.EBS := FALSE;
                    xInter.LDCOM := FALSE;
                    xInter.INSERT;
                END;
            UNTIL xCust.NEXT <= 0;

        COMMIT;
    end;

    procedure ApplyTransactions()
    var
        xTran: Record "FSN TranClienteLD";
        xJrnl: Record "Gen. Journal Line";
        xNum: Integer;
        xCust: Record Customer;
        xHist: Record "Detailed Cust. Ledg. Entry";
        xNxt: Code[20];
        NoSerieMgt: Codeunit NoSeriesManagement;
        GJBatch: Record "Gen. Journal Batch";
        TEXT000: Label 'No existe No serie en libro diario general';
    begin
        // Encontrar el siguiente correlativo de linea
        xJrnl.SETRANGE("Journal Template Name", 'RECEPCION');
        IF xJrnl.FIND('+') THEN xNum := xJrnl."Line No." + 10 ELSE xNum := 10000;
        CLEAR(xJrnl);
        CLEAR(xTran);

        xTran.SETRANGE(Posted, FALSE);
        IF xTran.FIND('-') THEN
            REPEAT
                IF (xTran."Retrieved from Receipt No" = '') AND (xTran."Refund Receipt No" = '') THEN BEGIN
                    // Buscar el codigo de cliente
                    CLEAR(xCust);
                    xCust.SETFILTER("No.", xTran."Customer No.");
                    IF xCust.FIND('-') THEN BEGIN
                        if NOT CheckBlockedCustOnJnls(xCust) then begin
                            IF xTran."Document Type" = xTran."Document Type"::Invoice THEN
                                xNxt := 'LDF-' + xTran."Document No."
                            ELSE
                                xNxt := 'LDP-' + xTran."Document No.";
                            xHist.RESET;
                            xHist.SETRANGE("Document No.", xNxt);
                            IF xHist.FIND('-') THEN BEGIN
                                // El documento resulta duplicado
                                xTran.Status := 'DUPL';
                                xTran.MODIFY;
                            END ELSE BEGIN
                                xJrnl.INIT;
                                xJrnl.VALIDATE("Journal Template Name", 'RECEPCION');
                                xJrnl.VALIDATE("Journal Batch Name", 'BANK');
                                xJrnl.VALIDATE("Line No.", xNum);
                                xJrnl.VALIDATE("Account Type", xJrnl."Account Type"::Customer);
                                xJrnl.VALIDATE("Account No.", xCust."No.");
                                xJrnl.VALIDATE("Posting Date", TODAY());
                                IF xTran."Document Type" = xTran."Document Type"::Invoice THEN BEGIN
                                    xJrnl.VALIDATE("Document Type", xJrnl."Document Type"::Invoice);
                                    //xJrnl.VALIDATE("Document No.", 'LDF-' + xTran."Document No.");
                                    if GJBatch.Get('RECEPCION', 'BANK') then
                                        xJrnl.VALIDATE("Document No.", NoSerieMgt.GetNextNo(GJBatch."No. Series", Today, TRUE))
                                    else
                                        Error(TEXT000);
                                    xJrnl.VALIDATE(Amount, xTran.Amount);
                                    xJrnl.Validate("External Document No.", 'LDF-' + xTran."Document No.");
                                END ELSE BEGIN
                                    xJrnl.VALIDATE("Document Type", xJrnl."Document Type"::Payment);
                                    //xJrnl.VALIDATE("Document No.", 'LDP-' + xTran."Document No.");
                                    if GJBatch.Get('RECEPCION', 'BANK') then
                                        xJrnl.VALIDATE("Document No.", NoSerieMgt.GetNextNo(GJBatch."No. Series", Today, TRUE))
                                    else
                                        Error(TEXT000);
                                    xJrnl.VALIDATE(Amount, xTran.Amount * -1);
                                    xJrnl.Validate("External Document No.", 'LDP-' + xTran."Document No.");
                                END;
                                xJrnl.VALIDATE("Bal. Account Type", xJrnl."Bal. Account Type"::"G/L Account");
                                //xJrnl.VALIDATE("Bal. Account No.", '110401001');
                                xJrnl.INSERT;

                                // Actualizando el registro de transaccion de LDCOM
                                xTran.Posted := TRUE;
                                xTran."Date Posted" := TODAY;
                                xTran."Time Posted" := TIME;
                                xTran.Status := 'POST';
                                xTran.MODIFY;

                                // Actualizando la base de datos
                                COMMIT;

                                // Siguiente
                                xNum += 10;
                            END;
                        end else begin
                            xTran.Status := 'FALTA';
                            xTran.MODIFY;
                        end;
                    END ELSE BEGIN
                        xTran.Status := 'FALTA';
                        xTran.MODIFY;
                    END;
                END;
            UNTIL xTran.NEXT <= 0;

        COMMIT;

        CLEAR(GenJrnlLine);
        GenJrnlLine.SETRANGE("Journal Template Name", 'RECEPCION');
        GenJrnlLine.SETRANGE("Journal Batch Name", 'BANK');
        GenJrnlLine.SETRANGE("Account Type", GenJrnlLine."Account Type"::Customer);
        IF GenJrnlLine.FINDSET THEN
            CODEUNIT.RUN(CODEUNIT::"Gen. Jnl.-Post", GenJrnlLine);

        COMMIT;
    end;

    procedure CheckBlockedCustOnJnls(Cust2: Record Customer): Boolean
    var
        Source: Option Journal,Document;
    begin
        with Cust2 do begin
            if Cust2."Privacy Blocked" then
                exit(true);

            if (Cust2.Blocked = Cust2.Blocked::All) or
               (Cust2.Blocked = Cust2.Blocked::Invoice)
            then
                exit(true);
        end;
    end;

    procedure ActualizaSaldos()
    var
        xCust: Record Customer;
        xInter: Record "FSN InterfazCreditos";
        xDIff: Decimal;
    begin
        xCust.RESET;
        xCust.SETFILTER("Credit Limit (LCY)", '>%1', 0);
        IF xCust.FIND('-') THEN
            REPEAT
                xCust.CALCFIELDS("Balance (LCY)", "LSC Amt. Charged On POS", "LSC Amt. Charged Posted");
                xInter.RESET;
                xInter.SETRANGE("Customer No.", xCust."No.");
                IF xInter.FIND('-') THEN BEGIN
                    // CSALX20170109 Verificar y/o actualizar el limite de credito en la tabla puente
                    IF xCust."Credit Limit (LCY)" <> xInter."Credit Limit" THEN BEGIN
                        xInter."Credit Limit" := xCust."Credit Limit (LCY)";
                        xInter.MODIFY;
                        COMMIT;
                    END;
                    // Comparar el saldo
                    xDIff := xInter.Balance - (xCust."Balance (LCY)" + xCust."LSC Amt. Charged On POS" - xCust."LSC Amt. Charged Posted");
                    IF xDIff <> 0 THEN BEGIN
                        // Ajustar Interfaz
                        xInter.Balance := (xCust."Balance (LCY)" + xCust."LSC Amt. Charged On POS" - xCust."LSC Amt. Charged Posted");
                        xInter.EBS := FALSE;
                        xInter.LDCOM := FALSE;
                        xInter.MODIFY;
                    END
                END ELSE BEGIN
                    // Insertar el registro
                    xInter.INIT;
                    xInter."Customer No." := xCust."No.";
                    xInter.ReferenciaEBS := xCust."FSN EBS Reference";
                    xInter."Credit Limit" := xCust."Credit Limit (LCY)";
                    xInter.Balance := (xCust."Balance (LCY)" + xCust."LSC Amt. Charged On POS" - xCust."LSC Amt. Charged Posted");
                    xInter.EBS := FALSE;
                    xInter.LDCOM := FALSE;
                    xInter.INSERT;
                END;
            UNTIL xCust.NEXT <= 0;

        COMMIT;
    end;


    procedure ApplyTransactionsDev()
    var
        xTran: Record "FSN TranClienteLD";
        //xJrnl: Record "Gen. Journal Line";
        xTra2: Record "FSN TranClienteLD";
        xJrnl2: Record "Gen. Journal Line";
        xCust: Record Customer;
        xNxt: Code[20];
        xNxt2: Code[20];
        xNumValue: Integer;
        DocType: Option Invoice,Payment,CreditNote;
        OldCustLedgEntry: Record "Cust. Ledger Entry";

        LineCount: Integer;
        ReceiptProcess: Code[20];
        Process: Boolean;
        NoOfRecords: Integer;
        DocumentNo: Code[20];
    begin
        CLEAR(xTran);
        CLEAR(xJrnl2);
        LineCount := 0;
        xJrnl2.SETRANGE("Journal Template Name", 'RECEPCION');
        IF xJrnl2.FIND('+') THEN xNumValue := xJrnl2."Line No." + 10 ELSE xNumValue := 10000;
        // Encontrar el siguiente correlativo de linea
        xTran.SETRANGE(Posted, FALSE);
        xTran.SetRange("Date Posted", today);
        xTran.SetFilter("Retrieved from Receipt No", '<>%1', '');
        IF xTran.FIND('-') THEN begin
            REPEAT
                LineCount := LineCount + 1;
                NoOfRecords := xTran.Count;
                Process := true;
                // Buscar el codigo de cliente
                CLEAR(xCust);
                xCust.SETFILTER("No.", xTran."Customer No.");
                IF xCust.FIND('-') THEN BEGIN
                    if NOT CheckBlockedCustOnJnls(xCust) then begin
                        if xTran."Refund Receipt No" <> '' then begin
                            xNxt2 := 'LDF-' + xTran."Document No.";
                            IF ValDuplicado(xNxt2) THEN BEGIN
                                // si documento resulta duplicado para factura
                                xTran.Status := 'DUPL';
                                xTran.MODIFY;
                                Process := false;
                            END else begin
                                xNxt := 'LDD-' + xTran."Document No.";
                                IF ValDuplicado(xNxt) THEN BEGIN
                                    //si el documento resulta duplicado para nota de credito
                                    xTran.Status := 'DUPL';
                                    xTran.MODIFY;
                                    Process := false;
                                END;
                            end;
                        end else begin
                            xTran.Status := 'FALTA';
                            xTran.MODIFY;
                            Process := false;
                        end;

                        if xTran.Amount = 0 then begin
                            xTran.Status := 'FALTA';
                            xTran.MODIFY;
                            Process := false;
                        end;

                        IF Process THEN BEGIN

                            OldCustLedgEntry.Reset();
                            OldCustLedgEntry.SetCurrentKey("Document No.");
                            OldCustLedgEntry.SetRange("Document No.", xTran."Retrieved from Receipt No");
                            OldCustLedgEntry.SetRange("Document Type", OldCustLedgEntry."Document Type"::Invoice);
                            OldCustLedgEntry.SetRange("Customer No.", xTran."Customer No.");
                            OldCustLedgEntry.SetRange(Open, true);
                            IF NOT OldCustLedgEntry.FindFirst() THEN begin
                                xTran.Status := 'FALTA';
                                xTran.MODIFY;
                                Process := false;
                            end;

                            OldCustLedgEntry.Reset();
                            OldCustLedgEntry.SetCurrentKey("Document No.");
                            OldCustLedgEntry.SetRange("Document No.", xTran."Refund Receipt No");
                            OldCustLedgEntry.SetRange("Document Type", OldCustLedgEntry."Document Type"::"Credit Memo");
                            OldCustLedgEntry.SetRange("Customer No.", xTran."Customer No.");
                            OldCustLedgEntry.SetRange(Open, true);
                            IF NOT OldCustLedgEntry.FindFirst() THEN begin
                                xTran.Status := 'FALTA';
                                xTran.MODIFY;
                                Process := false;
                            end;

                            IF Process THEN BEGIN
                                Clear(DocumentNo);

                                //Insert Journal Line Line para factura
                                InsertGenJournalLine(xTran, xCust, DocType::Invoice, xNumValue, DocumentNo);

                                // Actualizando el registro de transaccion de LDCOM
                                xTran.Posted := TRUE;
                                xTran."Date Posted" := TODAY;
                                xTran."Time Posted" := TIME;
                                xTran.Status := 'POST';
                                xTran.MODIFY;

                                // Siguiente
                                xNumValue += 10;

                                //Insert Journal Line Line para nota de credito
                                InsertGenJournalLine(xTran, xCust, DocType::CreditNote, xNumValue, DocumentNo);

                                // Actualizando el registro de transaccion de LDCOM
                                xTran.Posted := TRUE;
                                xTran."Date Posted" := TODAY;
                                xTran."Time Posted" := TIME;
                                xTran.Status := 'POST';
                                xTran.MODIFY;
                                // Actualizando la base de datos
                                COMMIT;

                                // Siguiente
                                xNumValue += 10;
                            END;
                        END;
                    end else begin
                        xTran.Status := 'FALTA';
                        xTran.MODIFY;
                    end;
                END ELSE BEGIN
                    xTran.Status := 'FALTA';
                    xTran.MODIFY;
                END;
            UNTIL xTran.NEXT <= 0;
        end;

        COMMIT;

        CLEAR(GenJrnlLine);
        GenJrnlLine.SETRANGE("Journal Template Name", 'RECEPCION');
        GenJrnlLine.SETRANGE("Journal Batch Name", 'BANK');
        GenJrnlLine.SETRANGE("Account Type", GenJrnlLine."Account Type"::Customer);
        IF GenJrnlLine.FINDSET THEN
            CODEUNIT.RUN(CODEUNIT::"Gen. Jnl.-Post", GenJrnlLine);

        COMMIT;
    end;

    procedure ValDuplicado(xNxtV: Code[20]): Boolean
    var
        xHist: Record "Detailed Cust. Ledg. Entry";
    begin
        // El documento resulta duplicado
        xHist.RESET;
        xHist.SETRANGE("Document No.", xNxtV);
        IF xHist.FIND('-') THEN
            exit(true)
        else
            exit(false);
    end;

    /*procedure InsertGenJournalLine(xTranT: Record "FSN TranClienteLD"; xCustT: Record Customer; DocTypeValue: Option Invoice,Payment,CreditNote; VAR xNum: Integer)
    var
        xJrnl: Record "Gen. Journal Line";
        NoSerieMgt: Codeunit NoSeriesManagement;
        GJBatch: Record "Gen. Journal Batch";
        OldCustLedgEntry: Record "Cust. Ledger Entry";
        TEXT000: Label 'No existe No serie en libro diario general';
    begin

        xJrnl.INIT;
        xJrnl.VALIDATE("Journal Template Name", 'RECEPCION');
        xJrnl.VALIDATE("Journal Batch Name", 'BANK');
        xJrnl.VALIDATE("Line No.", xNum);
        xJrnl.VALIDATE("Account Type", xJrnl."Account Type"::Customer);
        xJrnl.VALIDATE("Account No.", xCustT."No.");
        xJrnl.VALIDATE("Posting Date", TODAY());

        IF DocTypeValue = DocTypeValue::Invoice THEN BEGIN
            xJrnl.VALIDATE("Document Type", xJrnl."Document Type"::" ");
            if GJBatch.Get('RECEPCION', 'BANK') then
                xJrnl.VALIDATE("Document No.", NoSerieMgt.GetNextNo(GJBatch."No. Series", Today, TRUE))
            else
                Error(TEXT000);
            xJrnl.VALIDATE(Amount, xTranT.Amount * -1);
            xJrnl.VALIDATE(xJrnl."Credit Amount", xTranT.Amount * -1);
            xJrnl.Validate("External Document No.", 'LDF-' + xTranT."Document No.");
            xJrnl.VALIDATE("Applies-to Doc. Type", xJrnl."Applies-to Doc. Type"::Invoice);
            xJrnl."Applies-to Doc. No." := xTranT."Retrieved from Receipt No";
        END ELSE BEGIN
            if GJBatch.Get('RECEPCION', 'BANK') then
                xJrnl.VALIDATE("Document No.", NoSerieMgt.GetNextNo(GJBatch."No. Series", Today, TRUE))
            else
                Error(TEXT000);
            xJrnl.VALIDATE(Amount, xTranT.Amount * -1);
            xJrnl.VALIDATE("Debit Amount", xTranT.Amount * -1);
            xJrnl.VALIDATE("Document Type", xJrnl."Document Type"::" ");
            xJrnl.VALIDATE("Applies-to Doc. Type", xJrnl."Applies-to Doc. Type"::"Credit Memo");
            xJrnl."Applies-to Doc. No." := xTranT."Refund Receipt No";
            xJrnl.Validate("External Document No.", 'LDD-' + xTranT."Document No.");
        END;
        xJrnl.VALIDATE("Bal. Account Type", xJrnl."Bal. Account Type"::"G/L Account");
        xJrnl.VALIDATE("Bal. Account No.", '110401001');
        xJrnl.INSERT;

    end;*/

    procedure InsertGenJournalLine(xTranT: Record "FSN TranClienteLD"; xCustT: Record Customer; DocTypeValue: Option Invoice,Payment,CreditNote; VAR xNum: Integer; var DocumentNo: Code[20])
    var
        xJrnl: Record "Gen. Journal Line";
        NoSerieMgt: Codeunit NoSeriesManagement;
        GJBatch: Record "Gen. Journal Batch";
        OldCustLedgEntry: Record "Cust. Ledger Entry";
        TEXT000: Label 'No existe No serie en libro diario general';
    begin

        xJrnl.INIT;
        xJrnl.VALIDATE("Journal Template Name", 'RECEPCION');
        xJrnl.VALIDATE("Journal Batch Name", 'BANK');
        xJrnl.VALIDATE("Line No.", xNum);
        xJrnl.VALIDATE("Account Type", xJrnl."Account Type"::Customer);
        xJrnl.VALIDATE("Account No.", xCustT."No.");
        xJrnl.VALIDATE("Posting Date", TODAY());

        IF DocTypeValue = DocTypeValue::Invoice THEN BEGIN
            xJrnl.VALIDATE("Document Type", xJrnl."Document Type"::" ");
            if GJBatch.Get('RECEPCION', 'BANK') then begin
                xJrnl.VALIDATE("Document No.", NoSerieMgt.GetNextNo(GJBatch."No. Series", Today, TRUE));
                DocumentNo := xJrnl."Document No.";
            end else
                Error(TEXT000);
            xJrnl.VALIDATE(Amount, xTranT.Amount * -1);
            xJrnl.VALIDATE(xJrnl."Credit Amount", xTranT.Amount * -1);
            xJrnl.Validate("External Document No.", 'LDF-' + xTranT."Document No.");
            xJrnl.VALIDATE("Applies-to Doc. Type", xJrnl."Applies-to Doc. Type"::Invoice);
            xJrnl."Applies-to Doc. No." := xTranT."Retrieved from Receipt No";
        END ELSE BEGIN
            if GJBatch.Get('RECEPCION', 'BANK') then begin
                //xJrnl.VALIDATE("Document No.", NoSerieMgt.GetNextNo(GJBatch."No. Series", Today, TRUE));
                xJrnl.VALIDATE("Document No.", DocumentNo);
            end else
                Error(TEXT000);
            xJrnl.VALIDATE(Amount, xTranT.Amount * -1);
            xJrnl.VALIDATE("Debit Amount", xTranT.Amount * -1);
            xJrnl.VALIDATE("Document Type", xJrnl."Document Type"::" ");
            xJrnl.VALIDATE("Applies-to Doc. Type", xJrnl."Applies-to Doc. Type"::"Credit Memo");
            xJrnl."Applies-to Doc. No." := xTranT."Refund Receipt No";
            xJrnl.Validate("External Document No.", 'LDD-' + xTranT."Document No.");
        END;
        xJrnl.VALIDATE("Bal. Account Type", xJrnl."Bal. Account Type"::"G/L Account");
        //xJrnl.VALIDATE("Bal. Account No.", '110401001');
        xJrnl.INSERT;

    end;

}

