codeunit 50083 Test
{
    TableNo = "LSC Scheduler Job Header";
    trigger OnRun()
    var
        pqty: decimal;

    begin
        /*pqty := Round((4 / 10), 1, '=');
        Message('Test ', Format(pqty));*/

        case Code of

            'PROCESSJNL':
                begin
                    if not ValConfJournalTemplate(ErrorMesage) then
                        error(ErrorMesage);

                    ValidateExistJrnLine(ItemJrnLineProcess, 'RETAIL-INV');

                    ValidateExistJrnLine(ItemJrnLineProcess, 'RETINV-LOT');

                end;

            'PROCESSJNLGENERAL':
                begin
                    if not ValConfJournalTemplateGeneral(ErrorMesage) then
                        error(ErrorMesage);

                    GenJournalLine(GenJournalLineProcess, 'GENERAL');


                end;

        end;

    end;

    var
        ErrorMesage: text;
        ItemJrnLineProcess: Record "Item Journal Line";
        GenJournalLineProcess: Record "Gen. Journal Line";
        SalesJournal: Page "Sales Journal";

    procedure ValConfJournalTemplate(var ErrorText: Text): boolean
    var
        lText000: label 'plantilla diario producto %1 no está configurado.';
        lText001: Label 'Libro diario producto %1 no es de tipo Producto';
        lText002: Label 'Secciones diario productos %1 no está configurado en Item Journal Batch.';
        ItemJrnTemplate_l: Record "Item Journal Template";
        ItemJrnBatch_l: Record "Item Journal Batch";

    begin
        if not ItemJrnTemplate_l.Get('PRODUCTO') then begin
            ErrorText := STRSUBSTNO(lText000, 'PRODUCTO');
            exit(FALSE);
        end;

        IF (ItemJrnTemplate_l.Type <> ItemJrnTemplate_l.Type::Item) THEN BEGIN
            ErrorText := STRSUBSTNO(lText001, ItemJrnTemplate_l.Name);
            EXIT(FALSE);
        END;

        IF not ItemJrnBatch_l.GET(ItemJrnTemplate_l.Name, 'RETAIL-INV') THEN begin
            ErrorText := STRSUBSTNO(lText002, ItemJrnTemplate_l.Name);
            EXIT(FALSE);
        end;

        IF not ItemJrnBatch_l.GET(ItemJrnTemplate_l.Name, 'RETINV-LOT') THEN begin
            ErrorText := STRSUBSTNO(lText002, ItemJrnTemplate_l.Name);
            EXIT(FALSE);
        end;

        exit(TRUE);

    end;

    //Validate si existe jrnLine
    procedure ValidateExistJrnLine(var ItemJrnLine: Record "Item Journal Line"; BatchName: Code[10]): Boolean
    var
        Ok_: Boolean;
        ErrorText: Text;
    begin
        ItemJrnLine.reset;
        ItemJrnLine.SetRange(ItemJrnLine."Journal Template Name", 'PRODUCTO');
        ItemJrnLine.SetRange(ItemJrnLine."Journal Batch Name", BatchName);
        if ItemJrnLine.find('-') then
            repeat
                COMMIT;
                Ok_ := CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post", ItemJrnLine);
                //Si contiene
                IF NOT Ok_ THEN BEGIN
                    ErrorText := GETLASTERRORTEXT;
                END;
            until ItemJrnLine.Next() = 0;

    end;

    procedure GenJournalLine(var GenJournalLine: Record "Gen. Journal Line"; BatchName: Code[10]): Boolean
    var
        Ok_: Boolean;
        ErrorText: Text;
    begin
        GenJournalLine.reset;
        GenJournalLine.SetRange(GenJournalLine."Journal Template Name", 'RETAIL');
        GenJournalLine.SetRange(GenJournalLine."Journal Batch Name", BatchName);
        if GenJournalLine.find('-') then
            repeat
                COMMIT;
                Ok_ := CODEUNIT.Run(CODEUNIT::"Gen. Jnl.-Post", GenJournalLine);
                //Si contiene
                IF NOT Ok_ THEN BEGIN
                    ErrorText := GETLASTERRORTEXT;
                END;
            until GenJournalLine.Next() = 0;
    end;


    procedure ValConfJournalTemplateGeneral(var ErrorText: Text): boolean
    var
        lText000: label 'plantilla diario General %1 no está configurado.';
        lText001: Label 'Libro diario General %1 no es de tipo Venta';
        lText002: Label 'Secciones diario General %1 no está configurado en Gen. Journal Batch.';
        GeneralJournalTemplates: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";

    begin
        if not GeneralJournalTemplates.Get('RETAIL') then begin
            ErrorText := STRSUBSTNO(lText000, 'PRODUCTO');
            exit(FALSE);
        end;

        IF (GeneralJournalTemplates.Type <> GeneralJournalTemplates.Type::Sales) THEN BEGIN
            ErrorText := STRSUBSTNO(lText001, GeneralJournalTemplates.Name);
            EXIT(FALSE);
        END;

        IF not GenJournalBatch.GET(GeneralJournalTemplates.Name, 'GENERAL') THEN begin
            ErrorText := STRSUBSTNO(lText002, GeneralJournalTemplates.Name);
            EXIT(FALSE);
        end;

        exit(TRUE);

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post", 'OnBeforeCode', '', true, true)]
    local procedure "Gen. Jnl.-Post_OnBeforeCode"
    (
        var GenJournalLine: Record "Gen. Journal Line";
        var HideDialog: Boolean
    )
    begin
        if (GenJournalLine."Journal Template Name" = 'RETAIL') AND (GenJournalLine."Journal Batch Name" = 'GENERAL') then
            HideDialog := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post", 'OnBeforeCode', '', true, true)]
    local procedure "Item Jnl.-Post_OnBeforeCode"
    (
    var ItemJournalLine: Record "Item Journal Line";
    var HideDialog: Boolean;
    var SuppressCommit: Boolean;
    var IsHandled: Boolean
    )
    var
    begin
        if ItemJournalLine."Journal Batch Name" in ['RETAIL-INV', 'RETINV-LOT'] then
            HideDialog := true;
    end;

}