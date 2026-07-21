page 50025 "FSN Company List"
{
    Caption = 'Company List';
    PageType = List;
    SourceTable = "FSN Company Insurer";
    ApplicationArea = all;
    UsageCategory = Lists;
    layout
    {
        area(content)
        {
            group(General)
            {
                field(StoreCode; StoreCode)
                {
                    Caption = 'Validate for Store ';
                    TableRelation = "LSC Store"."No.";
                }
            }
            repeater(Group)
            {
                field("No."; "No.")
                {
                }
                field("Customer No."; "Customer No.")
                {
                    DrillDownPageID = "FSN Customers Select";
                    LookupPageID = "FSN Customers Select";
                }
                field(Description; Description)
                {
                }
                field("Coinsurance No."; "Coinsurance No.")
                {
                }
                field(Comission; Comission)
                {
                }
                field(Policy; Policy)
                {
                }
                field("Date Created"; "Date Created")
                {
                }
                field("Created by User"; "Created by User")
                {
                }
                field("Minimum Value"; "Minimum Value")
                {
                }
                field("Maximum Value"; "Maximum Value")
                {
                }
                field("Validate Recipe (Days)"; "Validate Recipe (Days)")
                {
                }
                field("Validate Auth No."; "Validate Auth No.")
                {
                }
                field("Validate Recipe"; "Validate Recipe")
                {
                }
                field("Recipe By Line"; "Recipe By Line")
                {
                }
                field("Send Maill"; "Send Maill")
                {
                }
                field("Mail In Status"; "Mail In Status")
                {
                }
                field("Mail Address"; "Mail Address")
                {
                }
                field(Inactive; Inactive)
                {
                }
                field("Store No."; "Store No.")
                {
                }
                field("Company Group"; "Company Group")
                {
                }
                field("User Filter Group for Cards"; "User Filter Group for Cards")
                {
                }
                field("Price Formula"; "Price Formula")
                {
                }
                field("Bill Alone"; "Bill Alone")
                {
                }
                field("Require Attachment Document"; "Require Attachment Document")
                {
                }
                field("Item No. Coinsurance"; "Item No. Coinsurance")
                {
                }
                field("Item No. Comission"; "Item No. Comission")
                {
                }
                field("Item No. Deductible"; "Item No. Deductible")
                {
                }
                field("Coinsurance Text Add"; "Coinsurance Text Add")
                {
                }
                field("Print Insured Links"; "Print Insured Links")
                {
                }
                field("Pre Authorize Require"; "Pre Authorize Require")
                {
                }
                field("Authorize Require"; "Authorize Require")
                {
                }
                field("Print Date In Invoice"; "Print Date In Invoice")
                {
                }
                field("Coinsurance Manual"; "Coinsurance Manual")
                {
                }
                field("Deductible Manual"; "Deductible Manual")
                {
                }
                field("Invoiced In Status Released"; "Invoiced In Status Released")
                {
                }
                field("Lookup Coinsurance"; "Lookup Coinsurance")
                {
                }
                field("Lookup Final Invoice"; "Lookup Final Invoice")
                {
                }
                field("Usar Remision"; "Usar Remision")
                {
                }
                field("Secondary Customer"; "Secondary Customer")
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
                action("Company Groups")
                {
                    Caption = 'Company Group';
                    Image = Group;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    RunObject = Page "FSN Company Groups";
                }
                action("Validate Company")
                {
                    Caption = 'Validate Company';
                    Image = Approval;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        ValiateSetup("No.", (StoreCode <> ''), StoreCode);
                        MESSAGE(Text000);
                    end;
                }
            }
        }
    }

    var
        StoreCode: Code[10];
        Text000: Label 'Successfull!';
}

