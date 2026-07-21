report 50009 "FSN Remission Transfer"
{
    // WVILLALTA 02.21                 - Validate Barcode in Transfer Line
    DefaultLayout = RDLC;
    RDLCLayout = 'src/Report/Layout/RemissionTransfer.rdl';


    dataset
    {
        dataitem(Theader; "Transfer Header")
        {
            DataItemTableView = SORTING("No.")
                                ORDER(Ascending);
            RequestFilterFields = "No.";
            column(No_; Theader."No.")
            {
            }
            column(FromCode; Theader."Transfer-from Code")
            {
            }
            column(FromDescr; Theader."Transfer-from Name")
            {
            }
            column(ToCode; Theader."Transfer-to Code")
            {
            }
            column(ToDescr; Theader."Transfer-to Name")
            {
            }
            column(PostDate; Theader."Posting Date")
            {
            }
            dataitem(Tline; "Transfer Line")
            {
                DataItemLink = "Document No." = FIELD("No.");
                DataItemTableView = SORTING("Document No.", "Line No.")
                                    ORDER(Ascending)
                                    WHERE("Derived From Line No." = CONST(0));
                column(BarCode; Barcode)
                {
                }
                column(Qty; Tline.Quantity)
                {
                }
                column(QtyToShip; Tline."Qty. to Ship")
                {
                }
                column(QtyShipped; Tline."Quantity Shipped")
                {
                }
                column(ItemNo; Tline."Item No.")
                {
                }
                column(Description; Tline.Description)
                {
                }
                column(QtyPerUnit; Tline."Qty. per Unit of Measure")
                {
                }
                dataitem(Item; Item)
                {
                    DataItemLink = "No." = FIELD("Item No.");
                    DataItemTableView = SORTING("No.")
                                        ORDER(Ascending);
                    column(UnitCost; Item."Unit Cost")
                    {
                    }
                }
                /*trigger OnPreDataItem()
                var
                    lText: Label 'No Filter is required';
                begin
                    if NoFilter = '' then
                        Error(lText);

                    Theader.SetRange("No.", NoFilter);
                end;*/

                trigger OnAfterGetRecord()
                var
                    Item_l: Record Item;
                begin
                    CLEAR(Barcode);
                    IF Tline."FSN Barcode No." <> '' THEN
                        Barcode := Tline."FSN Barcode No."
                    ELSE
                        IF Item_l.GET(Tline."Item No.") THEN
                            Barcode := Item_l."FSN Barcode No.";
                end;
            }
        }
    }
    /*requestpage
    {

        layout
        {
            area(content)
            {

                field(NoFilter; NoFilter)
                {
                    Caption = 'Documento No';
                }
            }
        }

        actions
        {
        }
    }
*/
    labels
    {
    }

    var
        Barcode: Code[20];
        NoFilter: Code[20];
}

