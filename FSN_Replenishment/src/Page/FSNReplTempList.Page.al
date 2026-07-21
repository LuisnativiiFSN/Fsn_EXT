page 50116 "FSN Replen. Template List"
{
    ApplicationArea = All;
    Caption = 'FSN Lista Libro Reaprov.';
    CardPageID = "LSC Replen. Template";
    Editable = false;
    PageType = List;
    SourceTable = "LSC Replen. Template";
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Control1100409000)
            {
                ShowCaption = false;
                field("Code"; Code)
                {
                    Caption = 'Código';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the code of the replenishment template.';
                }
                field(Description; Description)
                {
                    Caption = 'Descripción';
                    ApplicationArea = All;
                    ToolTip = 'Specifies a description of the replenishment template.';
                }
                field("Replenishment Type"; "Replenishment Type")
                {
                    Caption = 'Tipo Reaprovisionamiento';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the type of replenishment journal the template is used for.';
                }
                field("Location Code"; "Location Code")
                {
                    Caption = 'Código Almacén';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location that the items are transferred to, when used with Purchase Replenishment Journal, or the location that the items are transferred from, when used with Transfer Replenishment Journal.';
                }
                field("Purchase Order Type"; "Purchase Order Type")
                {
                    Caption = 'Tipo Pedido Compra';
                    ApplicationArea = All;
                    ToolTip = 'Specifies if Purchase Orders will be created for warehouse or receiving locations, and if cross docking is used. This field is only used with Purchase Replenishment Journal.';
                }
                field("Total Quantity"; "Total Quantity")
                {
                    Caption = 'Cantidad total';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total quantity (in Base UoM) of all journals in the Replen. Template.';
                }

                field("Vendor No. Filter"; "Vendor No. Filter")
                {
                    Caption = 'Filtro No. Proveedor';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor number that will be used to filter the items.';
                }
                field("Item Category Filter"; "Item Category Filter")
                {
                    Caption = 'Filtro Categoría Prod.';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item category that will be used to filter the items.';
                }
                field("Retail Product Filter"; "Retail Product Filter")
                {
                    Caption = 'Filtro Grupo Producto';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item product group that will be used to filter the items.';
                }
                field("Item No. Filter"; "Item No. Filter")
                {
                    Caption = 'Filtro No. Producto';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number that will be used to filter the items.';
                }
                field("Store Group Filter"; "Store Group Filter")
                {
                    Caption = 'Filtro Grupo Tienda';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the store group that will be used to filter the locations.';
                }
            }
        }
    }

    actions
    {
        area(navigation)
        {
            group("&Template")
            {
                Caption = 'Libro';
                action("Replenishment &Batches")
                {
                    ApplicationArea = All;
                    Caption = 'Secciones Reaprov.';
                    Image = Item;
                    RunObject = Page "LSC Replen. Worksheet Batches";
                    RunPageLink = "Replenishment Template Code" = FIELD(Code);
                    RunPageView = SORTING("Replenishment Template Code", "Batch No.");
                }
                action("&Edit Journal")
                {
                    ApplicationArea = All;
                    Caption = 'Matriz Recordar';
                    Image = OpenJournal;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ShortCutKey = 'Return';

                    trigger OnAction()
                    var
                        ReplenTemplate: Record "LSC Replen. Template";
                        ReplenJournalBatch: Record "LSC Replen. Journal Batch";
                        PurchaseReplenJournal: Page "LSC Purchase Replen. Journal";
                        TransferReplenJournal: Page "LSC Transfer Replen. Journal";
                        StoreStockRedistJournal: Page "LSC Redist. Journal";
                    begin
                        ReplenTemplate.Copy(Rec);
                        ReplenJournalBatch.Reset;
                        ReplenJournalBatch.SetRange("Replenishment Template Code", ReplenTemplate.Code);
                        if not ReplenJournalBatch.FindFirst then
                            Clear(ReplenJournalBatch);
                        if ReplenTemplate."Replenishment Type" = ReplenTemplate."Replenishment Type"::Purchase then begin
                            Clear(PurchaseReplenJournal);
                            PurchaseReplenJournal.SetCurrentTemplAndBatch(ReplenTemplate.Code, ReplenJournalBatch."Batch No.");
                            PurchaseReplenJournal.Run;
                        end else
                            if ReplenTemplate."Replenishment Type" = ReplenTemplate."Replenishment Type"::Redistribution then begin
                                Clear(StoreStockRedistJournal);
                                StoreStockRedistJournal.SetCurrentTemplAndBatch(ReplenTemplate.Code, ReplenJournalBatch."Batch No.");
                                StoreStockRedistJournal.Run;
                            end else begin
                                Clear(TransferReplenJournal);
                                TransferReplenJournal.SetCurrentTemplAndBatch(ReplenTemplate.Code, ReplenJournalBatch."Batch No.");
                                TransferReplenJournal.Run;
                            end;
                    end;
                }
            }
        }
        area(processing)
        {
            group("F&unctions")
            {
                Caption = 'Acciones';
                action("Delete All Lines")
                {
                    ApplicationArea = All;
                    Caption = 'Eliminar todas las Lineas';
                    Image = CancelAllLines;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        ReplenishJournalLines: Record "LSC Replen. Journal Lines";
                        ReplenishJournalDetails: Record "LSC Replen. Jrnl. Details";
                    begin
                        DeletedLinesCount := 0;
                        DeletedDetailsCount := 0;
                        if not Confirm(DeleteAllJournalLinesDetailsQst) then
                            exit;
                        Clear(ReplenishJournalDetails);
                        ReplenishJournalDetails.SetRange("Replenishment Template Code", Code);
                        if not ReplenishJournalDetails.IsEmpty then begin
                            DeletedDetailsCount += ReplenishJournalDetails.Count;
                            ReplenishJournalDetails.DeleteAll(true);
                        end;
                        Clear(ReplenishJournalLines);
                        ReplenishJournalLines.SetRange("Replenishment Template Code", Code);
                        if not ReplenishJournalLines.IsEmpty then begin
                            DeletedLinesCount += ReplenishJournalLines.Count;
                            ReplenishJournalLines.DeleteAll(true);
                        end;
                        Message(NoofJournalLineDetailDeleted, DeletedLinesCount, DeletedDetailsCount);
                    end;
                }
                action("Delete Zero Lines")
                {
                    ApplicationArea = All;
                    Caption = 'Eliminar Lineas Cero';
                    Image = CancelLine;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        ReplenishJournalLines: Record "LSC Replen. Journal Lines";
                        ReplenishJournalDetails: Record "LSC Replen. Jrnl. Details";
                    begin
                        DeletedLinesCount := 0;
                        DeletedDetailsCount := 0;
                        if not Confirm(DeleteAllZeroJournalLinesDetailsQst) then
                            exit;
                        Clear(ReplenishJournalDetails);
                        ReplenishJournalDetails.SetRange("Replenishment Template Code", Code);
                        ReplenishJournalDetails.SetRange(Quantity, 0);
                        if not ReplenishJournalDetails.IsEmpty then begin
                            DeletedDetailsCount += ReplenishJournalDetails.Count;
                            ReplenishJournalDetails.DeleteAll(true);
                        end;
                        Clear(ReplenishJournalLines);
                        ReplenishJournalLines.SetRange("Replenishment Template Code", Code);
                        ReplenishJournalLines.SetRange(Quantity, 0);
                        if not ReplenishJournalLines.IsEmpty then begin
                            DeletedLinesCount += ReplenishJournalLines.Count;
                            ReplenishJournalLines.DeleteAll(true);
                        end;
                        Message(NoofJournalLineDetailDeleted, DeletedLinesCount, DeletedDetailsCount);
                    end;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        //RefreshValue;
    end;

    var
        DeleteAllJournalLinesDetailsQst: Label 'Delete All Journal Lines and Details? ';
        DeleteAllZeroJournalLinesDetailsQst: Label 'Delete All Journal Lines and Details with Zero Quantity Only? ';
        NoofJournalLineDetailDeleted: Label '%1 of Journal Lines Deleted. \%2 of Journal Details Deleted.';
        DeletedLinesCount: Integer;
        DeletedDetailsCount: Integer;
        TotalCost: Decimal;
        TotalProfit: Decimal;
        TotalSales: Decimal;
        TotalRedistCost: Decimal;

    local procedure RefreshValue()
    var
        ReplenSetup: Record "LSC Replen. Setup";
    begin
        CalcFields("Total Cost Amount", "Total Profit Amount", "Total Sales Amount", "Total Redist. Cost Amount");
        TotalCost := 0;
        TotalSales := 0;
        TotalProfit := 0;
        TotalRedistCost := 0;
        ReplenSetup.Get;
        if "Replenishment Type" = "Replenishment Type"::Purchase then begin
            if ReplenSetup."Show Cost in Purch. Jnl." then
                TotalCost := "Total Cost Amount";
            if ReplenSetup."Show Profit in Purch. Jnl." then
                TotalProfit := "Total Profit Amount";
            if ReplenSetup."Show Sales in Purch. Jnl." then
                TotalSales := "Total Sales Amount";
        end else
            if "Replenishment Type" = "Replenishment Type"::Transfer then begin
                if ReplenSetup."Show Cost in Transf. Jnl." then
                    TotalCost := "Total Cost Amount";
                if ReplenSetup."Show Profit in Transf. Jnl." then
                    TotalProfit := "Total Profit Amount";
                if ReplenSetup."Show Sales in Transf. Jnl." then
                    TotalSales := "Total Sales Amount";
            end else
                if "Replenishment Type" = "Replenishment Type"::Redistribution then begin
                    if ReplenSetup."Show Cost in Redist. Jnl." then
                        TotalCost := "Total Cost Amount";
                    if ReplenSetup."Show Profit in Redist. Jnl." then
                        TotalProfit := "Total Profit Amount";
                    if ReplenSetup."Show Sales in Redist. Jnl." then
                        TotalSales := "Total Sales Amount";
                    if ReplenSetup."Show R. Cost in Redist. Jnl." then
                        TotalRedistCost := "Total Redist. Cost Amount";
                end;
    end;
}

