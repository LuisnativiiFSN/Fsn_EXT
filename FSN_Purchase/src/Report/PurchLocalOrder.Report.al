report 50047 "Purch Local Order"
{
    ApplicationArea = All;
    UsageCategory = Administration;
    PreviewMode = PrintLayout;
    DefaultLayout = RDLC;
    RDLCLayout = 'src/Report/Layout/PurchLocalOrder.rdl';
    Caption = 'FSN Purch Local Order';

    dataset
    {
        dataitem(PurchaseHeader; "Purchase Header")
        {
            DataItemTableView = WHERE("Document Type" = CONST("Order"));
            RequestFilterFields = "Location Code", "Order Date";
            column(PostingDate_PurchaseHeader; PurchaseHeader."Posting Date")
            {
            }
            column(OrderDate_PurchaseHeader; PurchaseHeader."Order Date")
            {
            }
            column(PaytoName_PurchaseHeader; PurchaseHeader."Pay-to Name")
            {
            }
            column(No_PurchaseHeader; PurchaseHeader."No.")
            {
            }
            column(Store_Name; StoreName)
            {
            }
            column(Company_name; CompanyFormerName)
            {
            }
            dataitem(PurchaseLine; "Purchase Line")
            {
                DataItemLink = "Document No." = FIELD("No.");
                column(Quantity_PurchaseLine; PurchaseLine.Quantity)
                {
                }
                column(DirectUnitCost_PurchaseLine; xSalesPrice)
                {
                }
                column(No_PurchaseLine; PurchaseLine."No.")
                {
                }
                column(Description_PurchaseLine; PurchaseLine.Description)
                {
                }
                column(BarcodeNo_PurchaseLine; PurchaseLine."FSN Barcode No.")
                {
                }
                dataitem(Item_g; Item)
                {
                    DataItemLink = "No." = FIELD("No.");
                    column(PrecioDNM_Item; Item_g."FSN Price DNM")
                    {
                    }
                    column(Barra_Item; Item_g."FSN Barcode No.")
                    {
                    }
                }

                trigger OnAfterGetRecord()
                begin
                    xSalesPrices.RESET;
                    xSalesPrices.SETRANGE("Item No.", "No.");
                    xSalesPrices.SETRANGE("Unit of Measure Code", "Unit of Measure Code");
                    IF xSalesPrices.FIND('-') THEN
                        xSalesPrice := xSalesPrices."LSC Unit Price Including VAT";
                end;
            }

            trigger OnPreDataItem()
            begin
                PurchaseHeader.SETRANGE(Status, Status::Released);
                Location := PurchaseHeader.GETFILTER("Location Code");

                RetailUser.RESET;
                RetailUser.SETRANGE(ID, USERID);
                IF RetailUser.FINDFIRST THEN BEGIN

                    IF (RetailUser."Location Code" = Location) OR (RetailUser."Location Code" = '') THEN
                        SETRANGE("Location Code", Location)
                    ELSE
                        ERROR(Txt0);
                END;

                Store.RESET;
                Store.SETRANGE(Store."Location Code", Location);
                IF Store.FINDFIRST THEN
                    StoreName := Store.Name
            end;
        }
    }

    requestpage
    {

        layout
        {
        }

        actions
        {
        }
    }

    labels
    {
    }

    trigger OnPreReport()
    begin
        CompanyInfo.RESET;
        CompanyInfo.SETRANGE("Name 2", COMPANYNAME);
        IF CompanyInfo.FINDFIRST THEN BEGIN
            CompanyFormerName := CompanyInfo.Name;
        END;
    end;

    var
        CompanyFormerName: Text[50];
        StoreName: Text[30];
        ItemSalesPrice: Decimal;
        Location: Code[20];
        xSalesPrice: Decimal;
        Store: Record "LSC Store";
        CompanyInfo: Record "Company Information";
        SalesPrice: Record "Sales Price";
        RetailUser: Record "LSC Retail User";
        xSalesPrices: Record "Sales Price";
        Txt0: Label 'User is not match with location';
}

