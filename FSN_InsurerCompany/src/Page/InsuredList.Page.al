page 50029 "FSN Insured List"
{
    // WVILLALTA23SEPT19           -  New page

    CardPageID = "FSN Insured Card";
    PageType = List;
    SourceTable = "FSN Insured Links";
    ApplicationArea = all;
    UsageCategory = Lists;
    Caption = 'Insured List';
    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Company No."; "Company No.")
                {
                }
                field(Card; Card)
                {
                }
                field("Customer No."; "Customer No.")
                {
                    DrillDownPageID = "FSN Customers Select";
                    LookupPageID = "FSN Customers Select";
                }
                field(Name; Name)
                {
                }
                field(Relation; Relation)
                {
                }
                field("Parent Card"; "Parent Card")
                {
                }
                field("Date Created"; "Date Created")
                {
                    Editable = false;
                }
                field("Created by User"; "Created by User")
                {
                    Editable = false;
                }
                field(Email; Email)
                {
                }
                field(Inactive; Inactive)
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
                action(CreateDocument)
                {
                    Caption = 'Create Document';
                    Image = DocumentEdit;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        Remission.RESET;
                        Remission.SETCURRENTKEY("Company No.", "Customer No.", Status);
                        Remission.SETRANGE(Remission."Company No.", "Company No.");
                        Remission.SETRANGE(Remission.Status, Remission.Status::Pending);
                        Remission.SETRANGE(Remission."Insured Card No.", Card);
                        IF Remission.FINDFIRST THEN BEGIN
                            MESSAGE(STRSUBSTNO(Text001, Card, Name));
                            RemissionCard.SETTABLEVIEW(Remission);
                            RemissionCard.RUN;
                        END ELSE BEGIN
                            CompanyLocal := "Company No.";
                            CompanyLocal := CompanyInsurer.SearchOtherCompany("Company No.", Card);

                            Clear(RetailUser);
                            if not RetailUser.Get(UserId) then
                                RetailUser.Init();
                            RetailSetup.GET();
                            if RetailUser."Store No." <> '' then
                                RetailSetup."Local Store No." := RetailUser."Store No.";

                            Remission.RESET;
                            Remission.SETCURRENTKEY("Company No.", "Customer No.", Status);
                            Remission.SETRANGE(Remission."Company No.", CompanyLocal);
                            Remission.SETRANGE(Remission.Status, Remission.Status::Pending);
                            Remission.SETRANGE(Remission."Insured Card No.", Card);
                            IF Remission.FINDFIRST THEN BEGIN
                                MESSAGE(STRSUBSTNO(Text001, Card, Name));
                                RemissionCard.SETTABLEVIEW(Remission);
                                RemissionCard.RUN;
                            END ELSE BEGIN
                                Remission.INIT();
                                Remission."No." := 'NEW';
                                Remission."Store No." := RetailSetup."Local Store No.";
                                Remission.VALIDATE("Company No.", CompanyLocal);
                                Remission.VALIDATE("Insured Card No.", Card);
                                Remission."No." := '';
                                Remission.VALIDATE("No.");
                                Remission.INSERT(TRUE);
                                COMMIT;
                                Remission2.RESET;
                                Remission2.SETRANGE(Remission2."Document Type", Remission."Document Type");
                                Remission2.SETRANGE(Remission2."No.", Remission."No.");
                                RemissionCard.SETTABLEVIEW(Remission2);
                                RemissionCard.RUN;
                            END;
                        END;
                    end;
                }
            }
        }
    }

    var
        Remission: Record "FSN Remission Header";
        Remission2: Record "FSN Remission Header";
        CompanyInsurer: Record "FSN Company Insurer";
        RemissionCard: Page "FSN Remission Card";
        RetailSetup: Record "LSC Retail Setup";
        RetailUser: Record "LSC Retail User";
        CompanyLocal: Code[10];
        Text001: Label 'Insured %1 %2 have a document pending';

}

