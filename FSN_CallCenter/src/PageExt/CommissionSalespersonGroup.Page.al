
pageextension 50090 "FSN CommissionSalespersonGr." extends "LSC Cmsn Salesperson Group"
{
    layout
    {
        addafter(Description)
        {
            field("FSN Require Input"; "FSN Require Input")
            {
            }
        }
    }

    actions
    {
        addafter("&Members")
        {
            action(ChannelType)
            {
                Caption = 'Channels Types';
                Image = NewToDo;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "FSN Call Center Channel Type";
                RunPageLink = "Type" = CONST(CallCenter),
                              "Line Type" = CONST(Parameter),
                              "Value No." = CONST('CHANNELTYPE');
            }
            action(PermissionChannel)
            {
                Caption = 'PermissionChannel';
                Image = ServiceTasks;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "FSN Channel Links";
                RunPageLink = "Type" = CONST(CallCenter),
                              "Line Type" = CONST(Parameter),
                              "Value No." = CONST('CHANNELGROUP'),
                              "Store No." = FIELD(Code);
            }
        }
    }
}