page 50035 "FSN Remission Subform"
{
    // WVILLALTA23SEPT19           - New page

    AutoSplitKey = true;
    Caption = 'Remission Subform';
    DelayedInsert = true;
    LinksAllowed = false;
    PageType = ListPart;
    SourceTable = "FSN Remission Line";
    SourceTableView = SORTING("Document Type", "Document No.", "Line No.")
                      ORDER(Ascending);

    layout
    {
        area(content)
        {
            group(General)
            {
                repeater(Group)
                {
                    field(Type; Type)
                    {
                        Editable = false;
                        Style = Favorable;
                        StyleExpr = (Type <> 0);

                        trigger OnValidate()
                        var
                        begin
                        end;
                    }
                    field(Barcode; Barcode)
                    {
                    }
                    field(Recipe; Recipe)
                    {
                    }
                    field("No."; "No.")
                    {
                        Editable = false;

                    }
                    field(Description; Description)
                    {
                        Editable = false;
                        Style = Favorable;
                        StyleExpr = (Type <> 0);
                    }
                    field("Unit of Measure"; "Unit of Measure")
                    {
                        Style = Favorable;
                        StyleExpr = (Type <> 0);
                    }
                    field(Quantity; Quantity)
                    {
                        DecimalPlaces = 0 : 0;
                        Style = Favorable;
                        StyleExpr = (Type <> 0);

                        trigger OnValidate()
                        begin
                            CurrPage.UPDATE;
                        end;
                    }
                    field("Unit Price Inc. VAT"; "Unit Price Inc. VAT")
                    {
                        AutoFormatType = 2;
                        DecimalPlaces = 2 : 2;
                        Editable = false;
                        Style = Favorable;
                        StyleExpr = (Type <> 0);
                    }
                    field("Discount %"; "Discount %")
                    {
                        Editable = false;
                        Style = Favorable;
                        StyleExpr = (Type <> 0);
                    }
                    field("Discount Amount"; "Discount Amount")
                    {
                        Editable = false;
                        Style = Favorable;
                        StyleExpr = (Type <> 0);
                    }
                    field("Amount Including VAT"; "Amount Including VAT")
                    {
                        Editable = false;
                        Style = Favorable;
                        StyleExpr = (Type <> 0);
                    }
                }
            }
            group(Totals)
            {
                field(TotalAmount; RemissionMgt.GetRemissionAmount("Document Type", "Document No."))
                {
                    Caption = 'Total Amount';
                }
                field(VATAmount; RemissionMgt.GetRemissionVATAmount("Document Type", "Document No."))
                {
                    Caption = 'VAT Amount';
                }
                field(AmountIncVAT; RemissionMgt.GetRemissionAmountIncVAT("Document Type", "Document No."))
                {
                    Caption = 'Amount Inc. VAT';
                }
                field(TotalCompanyInsure; RemissionMgt.GetRemissionTotalCompanyInsure("Document Type", "Document No."))
                {
                    Caption = 'Total Company Insure';
                    Style = Strong;
                    StyleExpr = TRUE;
                }
                field(Coinsurance; RemissionMgt.GetRemissionCoinsurance("Document Type", "Document No."))
                {
                    Caption = 'Coinsurance';
                }
                field(Comission; RemissionMgt.GetRemissionComission("Document Type", "Document No."))
                {
                    Caption = 'Comission';
                }
                field(TotalInsured; RemissionMgt.GetRemissionTotalInsured("Document Type", "Document No."))
                {
                    Caption = 'Total Insured';
                    Style = StrongAccent;
                    StyleExpr = TRUE;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(DeleteLine)
            {
                Caption = 'Delete Line';
                Image = Cancel;

                trigger OnAction()
                begin
                    Rec.DELETE(TRUE);
                end;
            }
        }
    }

    trigger OnDeleteRecord(): Boolean
    begin
        CurrPage.UPDATE(FALSE);
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        CurrPage.UPDATE(FALSE);
    end;

    trigger OnModifyRecord(): Boolean
    begin
        CurrPage.UPDATE(FALSE);
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        //CurrPage.UPDATE(FALSE);
    end;

    var
        RemissionMgt: Codeunit "FSN Remission Mgt.";
}

