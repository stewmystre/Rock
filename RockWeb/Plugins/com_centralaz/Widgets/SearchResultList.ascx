﻿<%@ Control Language="C#" AutoEventWireup="true" CodeFile="SearchResultList.ascx.cs" Inherits="RockWeb.Plugins.com_centralaz.Widgets.SearchResultList" %>

<asp:UpdatePanel ID="upnlContent" runat="server">
    <ContentTemplate>

        <asp:Panel runat="server" DefaultButton="btnButton">
            <Rock:RockTextBox ID="tbSearch" runat="server" AppendText="<i class='fa fa-search'></i>" />
            <asp:Button ID="btnButton" runat="server" OnClick="btnButton_Click" style="display:none" />
        </asp:Panel>

        <asp:Literal ID="lOutput" runat="server"></asp:Literal>

        <asp:Literal ID="lDebug" Visible="false" runat="server"></asp:Literal>

    </ContentTemplate>
</asp:UpdatePanel>

