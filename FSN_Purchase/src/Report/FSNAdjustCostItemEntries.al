report 50049 "FSN Adjust Cost - Item Entries"
{
    AdditionalSearchTerms = 'reenvío de costos';
    ApplicationArea = Basic, Suite;
    Caption = 'FSN Valorar stock - movs. producto';
    Permissions = TableData "Item Ledger Entry" = rimd,
                  TableData "Item Application Entry" = r,
                  TableData "Value Entry" = rimd,
                  TableData "Avg. Cost Adjmt. Entry Point" = rimd;
    ProcessingOnly = true;
    UsageCategory = Tasks;

    dataset
    {
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(FilterItemNo; ItemNoFilter)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Filtro nº prod.';
                        Editable = FilterItemNoEditable;
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            ItemList: Page "Item List";
                        begin
                            ItemList.LookupMode := true;
                            if ItemList.RunModal() = ACTION::LookupOK then
                                Text := ItemList.GetSelectionFilter()
                            else
                                exit(false);

                            exit(true);
                        end;
                    }
                    field(FilterItemCategory; ItemCategoryFilter)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Filtro categoría productos';
                        Editable = FilterItemCategoryEditable;
                        TableRelation = "Item Category";
                    }

                    field(ItemProdGroupFilter; ItemProdGroupFilter)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Filtro Grupo de productos';
                        Editable = FilterItemCategoryEditable;
                        TableRelation = "LSC Retail Product Group".Code;
                    }
                    field(Post; PostToGL)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Registrar en C/G';
                        Enabled = PostEnable;
                        trigger OnValidate()
                        var
                            ObjTransl: Record "Object Translation";
                        begin
                            if not PostToGL then
                                Message(
                                  ResynchronizeInfoMsg,
                                  ObjTransl.TranslateObject(ObjTransl."Object Type"::Report, REPORT::"Post Inventory Cost to G/L"));
                        end;
                    }
                }
            }
        }

        actions
        {
        }

        trigger OnInit()
        begin
            FilterItemCategoryEditable := true;
            FilterItemNoEditable := true;
            PostEnable := true;
        end;

        trigger OnOpenPage()
        begin
            InvtSetup.Get();
            PostToGL := InvtSetup."Automatic Cost Posting";
            PostEnable := PostToGL;
        end;
    }

    labels
    {
    }

    trigger OnPreReport()
    var
        ItemLedgEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        ItemApplnEntry: Record "Item Application Entry";
        AvgCostAdjmtEntryPoint: Record "Avg. Cost Adjmt. Entry Point";
        Item: Record Item;
        UpdateItemAnalysisView: Codeunit "Update Item Analysis View";
    begin
        OnBeforePreReport(ItemNoFilter, ItemCategoryFilter, ItemProdGroupFilter, PostToGL, Item);

        ItemApplnEntry.LockTable();
        if not ItemApplnEntry.FindLast then
            exit;
        ItemLedgEntry.LockTable();
        if not ItemLedgEntry.FindLast then
            exit;
        AvgCostAdjmtEntryPoint.LockTable();
        if AvgCostAdjmtEntryPoint.FindLast then;
        ValueEntry.LockTable();
        if not ValueEntry.FindLast then
            exit;

        if (ItemNoFilter <> '') and (ItemCategoryFilter <> '') and (ItemProdGroupFilter <> '') then
            Error(Text005);

        if ItemNoFilter <> '' then
            Item.SetFilter("No.", ItemNoFilter);
        if ItemCategoryFilter <> '' then
            Item.SetFilter("Item Category Code", ItemCategoryFilter);
        if ItemProdGroupFilter <> '' then
            Item.SetFilter("LSC Retail Product Code", ItemProdGroupFilter);

        InvtAdjmt.SetProperties(false, PostToGL);
        InvtAdjmt.SetFilterItem(Item);
        InvtAdjmt.MakeMultiLevelAdjmt;

        UpdateItemAnalysisView.UpdateAll(0, true);

        OnAfterPreReport;
    end;

    var
        ResynchronizeInfoMsg: Label 'Sus libros mayores y de artículos dejarán de sincronizarse después de ejecutar el ajuste de costos. Debe ejecutar el informe %1 para sincronizarlos de nuevo.';
        InvtSetup: Record "Inventory Setup";
        InvtAdjmt: Codeunit "Inventory Adjustment";
        ItemNoFilter: Text[250];
        ItemCategoryFilter: Text[250];
        ItemProdGroupFilter: Text[250];
        Text005: Label 'No debe utilizar el filtro de número de artículo y el filtro de categoría o Grupo de artículo al mismo tiempo.';
        PostToGL: Boolean;
        [InDataSet]
        PostEnable: Boolean;
        [InDataSet]
        FilterItemNoEditable: Boolean;
        [InDataSet]
        FilterItemCategoryEditable: Boolean;

    procedure InitializeRequest(NewItemNoFilter: Text[250]; NewItemCategoryFilter: Text[250])
    begin
        ItemNoFilter := NewItemNoFilter;
        ItemCategoryFilter := NewItemCategoryFilter;
    end;

    procedure SetPostToGL(NewPostToGL: Boolean)
    begin
        PostToGL := NewPostToGL;
    end;

    [IntegrationEvent(TRUE, false)]
    local procedure OnAfterPreReport()
    begin
    end;

    [IntegrationEvent(TRUE, false)]
    local procedure OnBeforePreReport(ItemNoFilter: Text[250]; ItemCategoryFilter: Text[250]; ItemProdGroupFilter: Text[250]; PostToGL: Boolean; var Item: Record Item)
    begin
    end;
}