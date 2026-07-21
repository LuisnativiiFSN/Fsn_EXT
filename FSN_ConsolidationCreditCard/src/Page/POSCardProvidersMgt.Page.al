page 50062 "FSN POS Card Providers Mgt" //60015 - 50103
{
    // WVILLALTA 9.20                      -  Check Card payment

    PageType = Document;

    layout
    {
        area(content)
        {
            field(WorksDate; FilterDateVar)
            {
                Caption = 'WorksDate';

                trigger OnValidate()
                begin
                    FilterView;
                end;
            }
            field(FilterPending; FilterPendingCheck)
            {
                Caption = 'Filter Pending';

                trigger OnValidate()
                begin
                    FilterView;
                end;
            }
            part(CardProviders; "FSN POS Card Providers")
            {
                Caption = 'Card Providers';
            }
            part(CardVSClient; "FSN POS Card Prov. VS Client")
            {
                Caption = 'Card VS Client';
                SubPageView = SORTING("Trans. Date", Close)
                              ORDER(Ascending);
            }
            part(ConfigPackageSubform; "Config. Package Subform") //8625
            {
                Editable = false;
                ShowFilter = false;
                SubPageView = WHERE("Package Code" = CONST('CREDITOS'),
                                    "Table ID" = CONST(50025));
            }
        }
    }

    actions
    {
        area(processing)
        {
            group(Sincronize)
            {
                action(SincronizeRecords)
                {
                    Caption = 'Sincronize Records';
                    Image = Change;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        COMMIT;
                        IF CONFIRM(STRSUBSTNO(Text001, FORMAT(FilterDateVar))) THEN
                            j := POSCardProviderMgt.CheckTransOpen(FilterDateVar, 5000);

                        IF j >= 5000 THEN
                            MESSAGE(Text002)
                        ELSE
                            MESSAGE(STRSUBSTNO(Text003, FORMAT(j)));

                        j := 0;
                    end;
                }
                action(ProcessAll)
                {
                    Caption = 'Process All';
                    Image = ChangeLog;
                    //The property 'PromotedIsBig' can only be set if the property 'Promoted' is set to 'true'
                    //PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        //ERROR('En Mantenimiento');
                        POSCardProviderMgt.ProcessTransactions(FilterDateVar);
                    end;
                }
                action("Update View")
                {
                    Caption = 'Update View';
                    Image = RefreshLines;
                    Promoted = true;
                    PromotedCategory = Category4;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        CurrPage.CardProviders.PAGE.SetWorkDate(FilterDateVar, FilterPendingCheck);
                        CurrPage.CardVSClient.PAGE.SetWorkDate(FilterDateVar, FilterPendingCheck);
                    end;
                }
            }
        }

        area(navigation)
        {
            action("POS Management")
            {
                Image = BinContent;

                trigger OnAction()
                var
                    PAGEPOSsetup: Page "FSN POS Setup Extend";
                begin
                    PAGEPOSsetup.FilterAdminCard;
                    PAGEPOSsetup.RUN;
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FilterView;
    end;

    trigger OnOpenPage()
    begin
        FilterView;
    end;

    var
        Location: Record "LSC Distribution Location";
        FilterDateVar: Date;
        FilterPendingCheck: Boolean;
        POSCardProviderMgt: Codeunit "FSN POS Card Providers Mgt.";
        Text001: Label 'Sincronize record from date %1?';
        j: Integer;
        Text002: Label 'Processing 5000 record maximum, try process again.';
        Text003: Label '%1 records processing.';


    procedure FilterView()
    begin
        CurrPage.CardProviders.PAGE.SetWorkDate(FilterDateVar, FilterPendingCheck);
        CurrPage.CardVSClient.PAGE.SetWorkDate(FilterDateVar, FilterPendingCheck);
    end;
}

