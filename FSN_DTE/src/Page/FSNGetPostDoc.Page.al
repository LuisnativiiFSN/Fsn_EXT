page 50160 "FSN Get Post Doc"
{
    Caption = 'Lines';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    PageType = List;
    SourceTable = "Sales Invoice Header";
    MultipleNewLines = false;

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                //ShowCaption = false;
                field("No"; "No.")
                {
                    //ApplicationArea = Basic, Suite;
                    //Lookup = false;
                    StyleExpr = 'Strong';
                }
                field("Shipment Date"; "Shipment Date")
                {
                    ApplicationArea = Basic, Suite;
                }
                field("Bill-to Customer No."; "Bill-to Customer No.")
                {
                    ApplicationArea = Basic, Suite;
                }
                field("Sell-to Customer No."; "Sell-to Customer No.")
                {
                    ApplicationArea = Basic, Suite;
                }

                field("Location Code"; "Location Code")
                {
                    ApplicationArea = Location;
                    Visible = false;
                }
                field("Shortcut Dimension 1 Code"; "Shortcut Dimension 1 Code")
                {
                    ApplicationArea = Dimensions;
                    Visible = false;
                }
                field("Shortcut Dimension 2 Code"; "Shortcut Dimension 2 Code")
                {
                    ApplicationArea = Dimensions;
                    Visible = false;
                }


            }
        }
    }

    procedure GetSelectedLine(FromSalesInvHeader: Record "Sales Invoice Header")
    var
        FromSalesInvLineCopy: Record "Sales Invoice Line";
        CopyDocMgt: Codeunit "Copy Document Mgt.";
        FromSalesShptLine: Record "Sales Shipment Line";
        FromSalesCrMemoLine: Record "Sales Cr.Memo Line";
        FromReturnRcptLine: Record "Return Receipt Line";
        FromSalesInvLine: Record "Sales Invoice Line";
        LinesNotCopied: Integer;
        MissingExCostRevLink: Boolean;

    begin
        FromSalesInvLineCopy.Reset();
        FromSalesInvLineCopy.SetRange(FromSalesInvLineCopy."Document No.", FromSalesInvHeader."No.");
        if FromSalesInvLineCopy.Find('-') then
            repeat
                FromSalesInvLine.Copy(FromSalesInvLineCopy);
            until FromSalesInvLineCopy.Next() = 0;

        CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
        CopyDocMgt.CopySalesLinesToDoc(
          "Sales Document Type From"::"Posted Invoice".AsInteger(), ToSalesHeader,
          FromSalesShptLine, FromSalesInvLine, FromReturnRcptLine, FromSalesCrMemoLine, LinesNotCopied, MissingExCostRevLink);

    end;

    procedure SetToSalesHeader(NewToSalesHeader: Record "Sales Header")
    begin
        ToSalesHeader := NewToSalesHeader;
    end;

    var
        ToSalesHeader: Record "Sales Header";
}

