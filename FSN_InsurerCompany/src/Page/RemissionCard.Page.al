page 50027 "FSN Remission Card"
{
    // WVILLALTA23SEPT19           - New page

    PageType = Document;
    RefreshOnActivate = true;
    SourceTable = "FSN Remission Header";
    ApplicationArea = all;
    UsageCategory = Documents;
    Caption = 'Remissión Card';
    layout
    {
        area(content)
        {
            group(General)
            {
                field("No."; "No.")
                {
                    Editable = false;
                }
                field("Company No."; "Company No.")
                {
                    Editable = EditLines;
                }
                field("Company Name"; "Company Name")
                {
                    Editable = false;
                }
                field("Store No."; "Store No.")
                {
                    Editable = false;
                    Lookup = false;
                }
                field("Posting Date"; "Posting Date")
                {
                }
                field("Document Date"; "Document Date")
                {
                    Editable = EditLines;
                }
                field(Status; Status)
                {
                    Editable = false;
                }
                field("Deductible Manual"; "Deductible Manual")
                {
                    Editable = EditLines;

                    trigger OnValidate()
                    begin
                        CurrPage.UPDATE;
                    end;
                }
                field("Sales Staff"; "Sales Staff")
                {
                    AssistEdit = false;
                    Editable = EditLines;
                }
                field("Insured Card No."; "Insured Card No.")
                {
                    Editable = EditLines;

                }
                field("Insured Name"; "Insured Name")
                {
                    Editable = false;
                }
                field(Relation; Relation)
                {
                    Editable = false;
                }
                field("Insured Parent Card No."; "Insured Parent Card No.")
                {
                    Editable = false;
                }
                field("Insured Parent Name"; "Insured Parent Name")
                {
                    Editable = false;
                }
                field("Coinsurance No."; "Coinsurance No.")
                {
                    Enabled = EditLines;

                    trigger OnValidate()
                    begin
                        CurrPage.UPDATE;
                    end;
                }
                field("Comission Apply"; "Comission Apply")
                {

                    trigger OnValidate()
                    begin
                        CurrPage.UPDATE;
                    end;
                }
            }

            part(RemissionLine; "FSN Remission Subform")
            {
                Editable = EditLines;
                SubPageLink = "Document Type" = FIELD("Document Type"),
                              "Document No." = FIELD("No.");
                SubPageView = SORTING("Document Type", "Document No.", "Line No.");
            }

        }
    }

    actions
    {
        area(processing)
        {
            group(Acciones)
            {
                action(Authorization)
                {
                    Image = Approve;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    RunObject = page "FSN Remission Authorization";
                    RunPageLink = "Document Type" = FIELD("Document Type"),
                                   "No." = FIELD("No.");
                    RunPageOnRec = true;
                }
                action(Release)
                {
                    Caption = 'Release';
                    Image = PostDocument;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        pError := FALSE;
                        RemissionMgt.PostRemission(Rec, pError, pTextError);
                        IF pError THEN
                            ERROR(pTextError);
                        EditLines := FALSE;
                        COMMIT;
                        RemissionMgt.PrintRemission(Rec);
                    end;
                }
                action(Print)
                {
                    Caption = 'Print';
                    Image = PrintReport;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        RemissionMgt.PrintViewRemission(Rec);
                    end;
                }
                action(Void)
                {
                    Caption = 'Void';
                    Image = CancelFALedgerEntries;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        IF NOT CONFIRM(Text002) THEN
                            EXIT;

                        RemissionMgt.SetStatus(Rec, 4, pError, pTextError);//4 Void
                        IF pError THEN
                            ERROR(pTextError);
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        EditLines := Status = Status::Pending;
    end;

    var
        RetailSetup: Record "LSC Retail Setup";
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        pError: Boolean;
        pTextError: Text;
        EditLines: Boolean;
        Text002: Label 'Do you want to void the document?';
}

