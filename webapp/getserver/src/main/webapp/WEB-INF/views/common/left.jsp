<%@ page language="java" import="java.util.*" pageEncoding="utf-8"%>
<div class="mainLeft">
			<div class="card">
				<div class="geneNav">
					<div class="geneNav_left">
						<div class="geneNav_right">
							<div class="geneNav_cont">
								<h3>企业名片</h3>
							</div>
						</div>
					</div>
				</div>
				<div class="geneCont">
					<ul>
						<li>电话：${company.telphone }</li>
						<li>邮编：${company.postcode }</li>
						<li>邮箱：${company.email }</li>
						<li>地址：${company.address }</li>
					</ul>
					<img src="${company.qrcode }" width="145" height="145" alt="二维码"/>
				</div>
				<div class="geneBottom">
					<div class="geneBottom_left">
						<div class="geneBottom_right">&nbsp;</div>
					</div>
				</div>
			</div>
			<div class="productNav">
				<div class="geneNav">
					<div class="geneNav_left">
						<div class="geneNav_right">
							<div class="geneNav_cont">
								<h3>产品导航</h3>
							</div>
						</div>
					</div>
				</div>
				<div class="geneCont">
					<ul>
						<%--
						<li><a href="###"><span>办公家具</span><em></em></a></li>
						<li><a href="###"><span>办公家具</span><em></em></a></li>
						<li><a href="###"><span>办公家具</span><em></em></a></li>
						<li><a href="###"><span>办公家具</span><em></em></a></li>
						<li><a href="###"><span>办公家具</span><em></em></a></li>
						<li><a href="###"><span>办公家具</span><em></em></a></li>
						--%>
						
						<li><a href="${ctx }/zhbx/product.html">&nbsp;&nbsp;综合布线</a></li>
						<li><a href="${ctx }/mjxt/product.html">&nbsp;&nbsp;门禁系统</a></li>
						<li><a href="${ctx }/afjk/product.html">&nbsp;&nbsp;安防监控</a></li>
						<li><a href="${ctx }/jtdh/product.html">&nbsp;&nbsp;集团电话</a></li>
						<li><a href="${ctx }/ledxsp/product.html">&nbsp;&nbsp;LED显示屏</a></li>
						<li><a href="${ctx }/bgjj/product.html">&nbsp;&nbsp;办公家具</a></li>
						
						
					</ul>
				</div>
				<div class="geneBottom">
					<div class="geneBottom_left">
						<div class="geneBottom_right">&nbsp;</div>
					</div>
				</div>
			</div>
			<div class="productNav">
				<div class="geneNav">
					<div class="geneNav_left">
						<div class="geneNav_right">
							<div class="geneNav_cont">
								<h3>企业动态</h3>
							</div>
						</div>
					</div>
				</div>
				<div class="geneCont">
					<ul>
						<li><a href="###"><span>暂无</span></a></li>
						<%--
						<li><a href="###"><span>办公家具</span></a></li>
						<li><a href="###"><span>办公家具</span></a></li>
						<li><a href="###"><span>办公家具</span></a></li>
						<li><a href="###"><span>办公家具</span></a></li>
						<li><a href="###"><span>办公家具</span></a></li>
						<li><a href="###"><span>办公家具</span></a></li>
						--%>
					</ul>
				</div>
				<div class="geneBottom">
					<div class="geneBottom_left">
						<div class="geneBottom_right">&nbsp;</div>
					</div>
				</div>
			</div>
		</div>
