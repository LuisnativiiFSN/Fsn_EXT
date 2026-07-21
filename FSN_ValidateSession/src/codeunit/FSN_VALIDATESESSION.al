codeunit 50059 "FSN VALIDATE SESSION J"
{
    SingleInstance = true;
    trigger OnRun()
    begin

    end;

    var
        POSSESION: Codeunit "LSC POS Session";
        ValPage: Page "FSN Validate Session Remision";
        Parameter: Record "FSN Parameter";


    //------------------------------------DEVOLUCIONES COMPRA-------Pedidos compra----------------------------------------------//


    [EventSubscriber(ObjectType::Page, Page::"Purchase Return Order", 'OnOpenPageEvent', '', true, true)]
    local procedure "Purchase Return Order_OnOpenPageEvent"(var Rec: Record "Purchase Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then //begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');

        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Purchase Return Order", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Purchase Return Order_OnInsertRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Purchase Return Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Purchase Return Order_OnModifyRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purch. Return Order", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Retail Purch. Return Order_OnOpenPageEvent"(var Rec: Record "Purchase Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then //begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purch. Return Order", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC Retail Purch. Return Order_OnInsertRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purch. Return Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "LSC Retail Purch. Return Order_OnModifyRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Purchase Return Order", 'OnPostDocumentBeforeNavigateAfterPosting', '', true, true)]
    local procedure "Purchase Return Order_OnPostDocumentBeforeNavigateAfterPosting"
    (
        var PurchaseHeader: Record "Purchase Header";
        var PostingCodeunitID: Integer;
        DocumentIsPosted: Boolean;
        var IsHandled: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    PurchaseHeader."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    DocumentIsPosted := false;
                //Error('Debe de llenar los datos de empleado');
            end else
                PurchaseHeader."Assigned User ID" := POSSESION.GetValue('VSESSION');
        end;
    end;

    /*------------------------------------------------------------PEDIDOS COMPRA------------------------------------------------------------------------------------*/


    [EventSubscriber(ObjectType::Page, Page::"Purchase Order", 'OnOpenPageEvent', '', true, true)]
    local procedure "Purchase Order_OnOpenPageEvent"(var Rec: Record "Purchase Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then //begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');

        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Order", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Purchase Order_OnInsertRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Purchase Order_OnModifyRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Order", 'OnPostDocumentBeforeNavigateAfterPosting', '', true, true)]
    local procedure "Purchase Order_OnPostDocumentBeforeNavigateAfterPosting"
    (
        var PurchaseHeader: Record "Purchase Header";
        var PostingCodeunitID: Integer;
        var Navigate: Enum "Navigate After Posting";
        DocumentIsPosted: Boolean;
        var IsHandled: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    PurchaseHeader."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                PurchaseHeader."Assigned User ID" := POSSESION.GetValue('VSESSION');
        end;
    end;
    /*---------------------------------------------------------------------------------------------------------------------------------------------------*/

    [EventSubscriber(ObjectType::Page, Page::"Blanket Purchase Order", 'OnOpenPageEvent', '', true, true)]
    local procedure "Blanket Purchase Order_OnOpenPageEvent"(var Rec: Record "Purchase Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then //begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Blanket Purchase Order", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Blanket Purchase Order_OnInsertRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Blanket Purchase Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Blanket Purchase Order_OnModifyRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;
    /*---------------------------------------------------------------------------------------------------------*/

    [EventSubscriber(ObjectType::Page, Page::"Warehouse Receipts", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Warehouse Receipts_OnModifyRecordEvent"
    (
        var Rec: Record "Warehouse Receipt Header";
        var xRec: Record "Warehouse Receipt Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Warehouse Receipts", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Warehouse Receipts_OnInsertRecordEvent"
    (
        var Rec: Record "Warehouse Receipt Header";
        var xRec: Record "Warehouse Receipt Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Warehouse Receipts", 'OnOpenPageEvent', '', true, true)]
    local procedure "Warehouse Receipts_OnOpenPageEvent"(var Rec: Record "Warehouse Receipt Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then //begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
        end;
    end;

    /*--------------------------------------------------------------Facturas compra----------------------------------------------------------------------------*/

    [EventSubscriber(ObjectType::Page, Page::"Purchase Invoice", 'OnOpenPageEvent', '', true, true)]
    local procedure "Purchase Invoice_OnOpenPageEvent"(var Rec: Record "Purchase Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then //begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Invoice", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Purchase Invoice_OnInsertRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Invoice", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Purchase Invoice_OnModifyRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Invoice", 'OnPostDocumentBeforeNavigateAfterPosting', '', true, true)]
    local procedure "Purchase Invoice_OnPostDocumentBeforeNavigateAfterPosting"
    (
        var PurchaseHeader: Record "Purchase Header";
        var PostingCodeunitID: Integer;
        var Navigate: Enum "Navigate After Posting";
        DocumentIsPosted: Boolean;
        var IsHandled: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    PurchaseHeader."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                PurchaseHeader."Assigned User ID" := POSSESION.GetValue('VSESSION');
        end;
    end;
    //-------------------------------------------------Cotizacion compra-----------------------------------------------------------//

    [EventSubscriber(ObjectType::Page, Page::"Purchase Quote", 'OnOpenPageEvent', '', true, true)]
    local procedure "Purchase Quote_OnOpenPageEvent"(var Rec: Record "Purchase Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then //begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Purchase Quote", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Purchase Quote_OnInsertRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Purchase Quote", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Purchase Quote_OnModifyRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    /*---------------------------------------------------------Evento de tabla----------------------------------------------------------------*/

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Purchase Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Purchase Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION')
            end else
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
    end;


    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Purchase Header_OnBeforeModifyEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    XRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end;
            end else begin
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
    end;


    //---------------------------------------Lista Recepción Com. Min.------------------------------------------------//
    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Retail Receiving_OnOpenPageEvent"(var Rec: Record "LSC P/R Counting Header")
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    Message('Debe ingresar un usuario')
                else
                    if POSSESION.GetValue('VSESSION') <> '' then
                        Rec."FSN User" := POSSESION.GetValue('VSESSION');
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC Retail Receiving_OnInsertRecordEvent"
    (
        var Rec: Record "LSC P/R Counting Header";
        var xRec: Record "LSC P/R Counting Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    BelowxRec := false
                else
                    if POSSESION.GetValue('VSESSION') <> '' then
                        Rec."FSN User" := POSSESION.GetValue('VSESSION')
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnModifyRecordEvent', '', true, true)]
    local procedure "LSC Retail Receiving_OnModifyRecordEvent"
    (
        var Rec: Record "LSC P/R Counting Header";
        var xRec: Record "LSC P/R Counting Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowModify := false
                else
                    if POSSESION.GetValue('VSESSION') <> '' then
                        Rec."FSN User" := POSSESION.GetValue('VSESSION')
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC P/R Counting Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC P/R Counting Header_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC P/R Counting Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."FSN User" := POSSESION.GetValue('VSESSION')
            end else
                Rec."FSN User" := POSSESION.GetValue('VSESSION');
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC P/R Counting Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC P/R Counting Header_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC P/R Counting Header";
        var xRec: Record "LSC P/R Counting Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."FSN User" := POSSESION.GetValue('VSESSION');
            end else
                Rec."FSN User" := POSSESION.GetValue('VSESSION');
        end;
    end;

    //------------------------------------------------------------------Solicitudes Transferencia-------------------------------------------------------------//

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Order", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Retail Transfer Order_OnOpenPageEvent"(var Rec: Record "Transfer Header")
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION')
            end else
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Order", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC Retail Transfer Order_OnInsertRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "LSC Retail Transfer Order_OnModifyRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;




    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Requests", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Retail Transfer Requests_OnOpenPageEvent"(var Rec: Record "Transfer Header")
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION')
            end else
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Requests", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC Retail Transfer Requests_OnInsertRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Requests", 'OnModifyRecordEvent', '', true, true)]
    local procedure "LSC Retail Transfer Requests_OnModifyRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    //--------------------------------------------------------------Transferencias Pendientes de Picking------------------------------------------------------//


    [EventSubscriber(ObjectType::Page, Page::"LSC Transfers To Be Picked", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Transfers To Be Picked_OnOpenPageEvent"(var Rec: Record "Transfer Header")
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION')
            end else
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Transfers To Be Picked", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC Transfers To Be Picked_OnInsertRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Transfers To Be Picked", 'OnModifyRecordEvent', '', true, true)]
    local procedure "LSC Transfers To Be Picked_OnModifyRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnAfterInsertEvent', '', true, true)]
    local procedure "Transfer Header_OnAfterInsertEvent"
    (
        var Rec: Record "Transfer Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION')
            end else
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Transfer Header_OnBeforeModifyEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    //--------------------------------------------Pedidos de transferencia-------------------------------------------//


    [EventSubscriber(ObjectType::Page, Page::"Transfer Orders", 'OnOpenPageEvent', '', true, true)]
    local procedure "Transfer Orders_OnOpenPageEvent"(var Rec: Record "Transfer Header")
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION')
            end else
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
    end;

    [EventSubscriber(ObjectType::Page, Page::"Transfer Orders", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Transfer Orders_OnInsertRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Transfer Orders", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Transfer Orders_OnModifyRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                    xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
                xRec."LSC Buyer ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;

    //--------------------------------------------Recepciones almacén---------------------------------------------//

    [EventSubscriber(ObjectType::Page, Page::"Warehouse Receipt", 'OnOpenPageEvent', '', true, true)]
    local procedure "Warehouse Receipt_OnOpenPageEvent"(var Rec: Record "Warehouse Receipt Header")
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION')
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
    end;


    [EventSubscriber(ObjectType::Page, Page::"Warehouse Receipt", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Warehouse Receipt_OnInsertRecordEvent"
    (
        var Rec: Record "Warehouse Receipt Header";
        var xRec: Record "Warehouse Receipt Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION')
                end else
                    AllowInsert := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Warehouse Receipt", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Warehouse Receipt_OnModifyRecordEvent"
    (
        var Rec: Record "Warehouse Receipt Header";
        var xRec: Record "Warehouse Receipt Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION')
                end else
                    AllowModify := false;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;



    [EventSubscriber(ObjectType::Table, Database::"Warehouse Receipt Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Warehouse Receipt Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Warehouse Receipt Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION')
            end else
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Receipt Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Warehouse Receipt Header_OnBeforeModifyEvent"
    (
        var Rec: Record "Warehouse Receipt Header";
        var xRec: Record "Warehouse Receipt Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                    xRec."Assigned User ID" := POSSESION.GetValue('VSESSION')
                end;
            end else begin
                Rec."Assigned User ID" := POSSESION.GetValue('VSESSION');
                xRec."Assigned User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;
    //-----------------------------------------------------------------------------------------------//

    [EventSubscriber(ObjectType::Page, Page::"LSC Stock Request", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Stock Request_OnOpenPageEvent"(var Rec: Record "LSC InStore Stock Req. Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    Message('Debe ingresar un usuario');
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Stock Request", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC Stock Request_OnInsertRecordEvent"
    (
        var Rec: Record "LSC InStore Stock Req. Header";
        var xRec: Record "LSC InStore Stock Req. Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowInsert := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Stock Request", 'OnModifyRecordEvent', '', true, true)]
    local procedure "LSC Stock Request_OnModifyRecordEvent"
    (
        var Rec: Record "LSC InStore Stock Req. Header";
        var xRec: Record "LSC InStore Stock Req. Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowModify := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Sales Order", 'OnOpenPageEvent', '', true, true)]
    local procedure "Sales Order_OnOpenPageEvent"(var Rec: Record "Sales Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    Message('Debe ingresar un usuario');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Sales Order", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Sales Order_OnInsertRecordEvent"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowInsert := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Sales Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Sales Order_OnModifyRecordEvent"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowModify := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Sales Return Order", 'OnOpenPageEvent', '', true, true)]
    local procedure "Sales Return Order_OnOpenPageEvent"(var Rec: Record "Sales Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    Message('Debe ingresar un usuario');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Sales Return Order", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Sales Return Order_OnInsertRecordEvent"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowInsert := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Sales Return Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Sales Return Order_OnModifyRecordEvent"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowModify := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Warehouse Shipment", 'OnOpenPageEvent', '', true, true)]
    local procedure "Warehouse Shipment_OnOpenPageEvent"(var Rec: Record "Warehouse Shipment Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    Message('Debe ingresar un usuario');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Warehouse Shipment", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Warehouse Shipment_OnInsertRecordEvent"
    (
        var Rec: Record "Warehouse Shipment Header";
        var xRec: Record "Warehouse Shipment Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowInsert := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Warehouse Shipment", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Warehouse Shipment_OnModifyRecordEvent"
    (
        var Rec: Record "Warehouse Shipment Header";
        var xRec: Record "Warehouse Shipment Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowModify := false;
            end;
        end;
    end;

    //---------------------------------------------------------------------------------------------------------------------//

    [EventSubscriber(ObjectType::Page, Page::"LSC InStore Stock Req. Store", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC InStore Stock Req. Store_OnOpenPageEvent"(var Rec: Record "LSC InStore Stock Req. Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    Message('Debe ingresar un usuario');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC InStore Stock Req. Store", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC InStore Stock Req. Store_OnInsertRecordEvent"
    (
        var Rec: Record "LSC InStore Stock Req. Header";
        var xRec: Record "LSC InStore Stock Req. Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowInsert := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC InStore Stock Req. Store", 'OnModifyRecordEvent', '', true, true)]
    local procedure "LSC InStore Stock Req. Store_OnModifyRecordEvent"
    (
        var Rec: Record "LSC InStore Stock Req. Header";
        var xRec: Record "LSC InStore Stock Req. Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') = '' then
                    AllowModify := false;
            end;
        end;
    end;

    //---------------------------------------Historicos-------------------------------------------------//

    [EventSubscriber(ObjectType::Page, Page::"Posted Return Shipment", 'OnOpenPageEvent', '', true, true)]
    local procedure "Posted Return Shipment_OnOpenPageEvent"(var Rec: Record "Return Shipment Header")
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."User ID" := POSSESION.GetValue('VSESSION');
                end;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Posted Return Shipment", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Posted Return Shipment_OnInsertRecordEvent"
    (
        var Rec: Record "Return Shipment Header";
        var xRec: Record "Return Shipment Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."User ID" := POSSESION.GetValue('VSESSION');
                    xRec."User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowInsert := false;
            end else begin
                Rec."User ID" := POSSESION.GetValue('VSESSION');
                xRec."User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Posted Return Shipment", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Posted Return Shipment_OnModifyRecordEvent"
    (
        var Rec: Record "Return Shipment Header";
        var xRec: Record "Return Shipment Header";
        var AllowModify: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                Commit();
                Clear(ValPage);
                ValPage.RunModal();
                if POSSESION.GetValue('VSESSION') <> '' then begin
                    Rec."User ID" := POSSESION.GetValue('VSESSION');
                    xRec."User ID" := POSSESION.GetValue('VSESSION');
                end else
                    AllowModify := false;
            end else begin
                Rec."User ID" := POSSESION.GetValue('VSESSION');
                xRec."User ID" := POSSESION.GetValue('VSESSION');
            end;
        end;
    end;


    //-----------------------------------------------------------------------------------------------//
    procedure SessionParametro(): Boolean
    var
        valor: Text;
        usuario: Text;
        Inuser: Integer;
        p: Page 99009501;
    begin
        //Inuser := StrLen(UserId);
        Inuser := StrLen(UserId);
        if Inuser > 20 then
            usuario := CopyStr(UserId, 8)
        else
            usuario := UserId;
        exit((Parameter.Get('SESSIONR', usuario)) AND (Parameter.Activo));
    end;



    [EventSubscriber(ObjectType::Page, Page::"Posted Return Shipments", 'OnOpenPageEvent', '', true, true)]
    local procedure "Posted Return Shipments_OnOpenPageEvent"(var Rec: Record "Return Shipment Header")
    var
        lRetailUser: Record "LSC Retail User";
    begin
        if Rec.GetFilters = '' then
            if lRetailUser.Get(UserId) then
                if (lRetailUser."Store No." <> '') then begin
                    Rec.FilterGroup(2);
                    Rec.SetRange(Rec."LSC Store No.", lRetailUser."Store No.");
                    Rec.FilterGroup(0);
                end;
    end;

    //-----------------------------------------------Tablas-----------------------------------------------------//


    [EventSubscriber(ObjectType::Table, Database::"Purch. Rcpt. Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Purch. Rcpt. Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Purch. Rcpt. Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."FSN User" := POSSESION.GetValue('VSESSION');
            end else
                Rec."FSN User" := POSSESION.GetValue('VSESSION');

        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Purch. Inv. Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Purch. Inv. Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Purch. Inv. Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."FSN User" := POSSESION.GetValue('VSESSION');
            end else
                Rec."FSN User" := POSSESION.GetValue('VSESSION');

        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Receipt Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Transfer Receipt Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Transfer Receipt Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."FSN User" := POSSESION.GetValue('VSESSION');
            end else
                Rec."FSN User" := POSSESION.GetValue('VSESSION');

        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Shipment Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Transfer Shipment Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Transfer Shipment Header";
        RunTrigger: Boolean
    )
    begin
        IF SessionParametro then begin
            if POSSESION.GetValue('VSESSION') = '' then begin
                if POSSESION.GetValue('VSESSION') <> '' then
                    Rec."FSN User" := POSSESION.GetValue('VSESSION');
            end else
                Rec."FSN User" := POSSESION.GetValue('VSESSION');

        end;
    end;



}