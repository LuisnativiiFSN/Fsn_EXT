page 50036 "FSN Remission List"
{
    // WVILLALTA23SEPT19           - New page

    Caption = 'Remission List';
    CardPageID = "FSN Remission Card";
    Editable = false;
    PageType = List;
    //Permissions = TableData 50052 = ri;
    SourceTable = "FSN Remission Header";
    ApplicationArea = all;
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; "No.")
                {
                }
                field("External Document No."; "External Document No.")
                {
                }
                field("Company Name"; "Company Name")
                {
                }
                field("Sales Staff"; "Sales Staff")
                {
                }
                field("Insured Card No."; "Insured Card No.")
                {
                }
                field("Insured Name"; "Insured Name")
                {
                }
                field(Relation; Relation)
                {
                }
                field(Status; Status)
                {
                    Style = Attention;
                    StyleExpr = (Status = 0);
                }
                field("Amount Including VAT"; "Amount Including VAT")
                {
                }
                field("Coinsurance No."; "Coinsurance No.")
                {
                }
                field("Document Date"; "Document Date")
                {
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            group(Process)
            {
                action(Authorization)
                {
                    Image = Approve;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    RunObject = Page "FSN Remission Authorization";
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
                        RemissionMgt.verifyValidation(Rec, pError, pTextError);
                        IF pError THEN
                            ERROR(pTextError);
                        pError := FALSE;
                        RemissionMgt.PostRemission(Rec, pError, pTextError);
                        IF pError THEN
                            ERROR(pTextError);
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
                action("Reverse Status")
                {
                    Caption = 'Reverse Status';
                    Image = GetEntries;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        IF Status = Status::Pending THEN
                            ERROR('');

                        IF NOT CONFIRM(Text003) THEN EXIT;

                        IF Status < 0 THEN BEGIN
                            Status := Status::Pending;
                            MODIFY;
                            EXIT;
                        END ELSE
                            RemissionMgt.SetStatus(Rec, (Status - 1), pError, pTextError);
                        Rec.GET("Document Type", "No.");
                        IF pError THEN BEGIN
                            ERROR(pTextError);
                        END ELSE
                            MESSAGE(STRSUBSTNO(Text001, FORMAT(Rec.Status)));
                    end;
                }
            }
        }
    }

    var
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        pError: Boolean;
        pTextError: Text;
        Text001: Label 'New status:  %1';
        Text002: Label 'Do you want to void the document?';
        Text003: Label 'Do you want reverse status?';
}

