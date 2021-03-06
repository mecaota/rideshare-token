pragma solidity ^0.5.2;

import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC721/ERC721Enumerable.sol";
import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/payment/PullPayment.sol";
      
/**
 * @title ERC721FullMock
 * This mock just provides a public mint and burn functions for testing purposes,
 * and a public setter for metadata URI
 */
contract RideshareDemand is ERC721Enumerable, PullPayment{
    
    struct Spot{
        string name;
        int32 latitude;
        int32 longitude;
    }
    
    struct Demand{
        address purchaser;
        uint256 item_id;
        uint256 price;
        uint256 est_date;
        Spot dept;
        Spot arrv;
    }
    
    event BoughtDemand(uint256 indexed demand_id, uint256 price);
    event ChangeDemand(uint256 indexed demand_id, string changed);
    //event TicketAuthorized(address indexed purchaser, address indexed minter, uint indexed demandId);
    
    mapping(uint256=>Demand) private _demands; // token_id to demand(=item_id) struct
    mapping(uint256=>uint256[]) private _itemid2demand; // item_id to demand
    
    uint256 private _nextTokenId = 0;
    int32 private max_latitude = 900000000;
    int32 private min_latidude = -900000000;
    int32 private max_longitude = 1800000000;
    int32 private min_longitude = -1800000000;

    function _generateTokenId() private returns(uint256) {
        _nextTokenId = _nextTokenId.add(1);
        return _nextTokenId;
    }
    
    function mintDemands(
        uint8 passengers,
        uint256 price,
        uint256 est_date,
        string memory dept_name,
        int32 dept_latitude,
        int32 dept_longitude,
        string memory arrv_name,
        int32 arrv_latitude,
        int32 arrv_longitude
        )
        public
        returns (bool)
        {   
            require(bytes(dept_name).length!=0 || bytes(arrv_name).length!=0 || passengers!=0);
            require(min_latidude<=dept_latitude && dept_latitude<=max_latitude && min_longitude<=dept_longitude && dept_longitude<=max_longitude);
            require(min_latidude<=arrv_latitude && arrv_latitude<=max_latitude && min_longitude<=arrv_longitude && arrv_longitude<=max_longitude);
            if(balanceOf(msg.sender) > 0){
                for(uint256 i = 0; i < balanceOf(msg.sender); i++){
                    require(_isOwnBoughtDemand(tokenOfOwnerByIndex(msg.sender, i)));
                }
            }
            uint256 item_id = 0;
            for(uint i=0; i<passengers; i++){
                uint256 demand_id = _generateTokenId();
                super._mint(msg.sender, demand_id);
                if(i==0){
                    item_id = demand_id;
                }
                _itemid2demand[item_id].push(demand_id);
            }
            _updateDemandToken(
                    item_id,
                    price,
                    est_date,
                    dept_name,
                    dept_latitude,
                    dept_longitude,
                    arrv_name,
                    arrv_latitude,
                    arrv_longitude
                    );
            return true;
        }
        
    function burn(uint256 demand_id) public {
        require(_isApprovedOrOwner(msg.sender, demand_id));
        if(_isBurnable(demand_id)){
            super._burn(msg.sender, demand_id);
            delete _demands[demand_id];
        }
    }
        
    function cleanMintedDemand() public {
        for(uint256 i = 0; i < balanceOf(msg.sender); i++){
            uint256 demand_id = tokenOfOwnerByIndex(msg.sender, i);
            if(!_isOwnBoughtDemand(demand_id)){
                burn(demand_id);
            }
        }
    }
    
    // If not purchased, return true. If purchased demand, bought and timeover demand is true. 
    function _isBurnable(uint256 demand_id) private view returns(bool){
        return _isPurchesed(demand_id) ? _isOwnBoughtDemand(demand_id)&&_isTimeOver(demand_id) : true;
    }
    
    // If purchaser is msg.sender, return true
    function _isOwnBoughtDemand(uint256 demand_id) private view returns(bool){
        return (_demands[demand_id].purchaser==msg.sender);
    }
    
    // If purchaser is not null, return true
    function _isPurchesed(uint256 demand_id) private view returns(bool){
        return (_demands[demand_id].purchaser!=address(0));
    }
    
    function _isTimeOver(uint256 demand_id) private view returns(bool){
        return (_demands[demand_id].est_date<=block.timestamp);
    }
    
    function approveAllMintedTickets() public {
        for(uint256 i = 0; i < balanceOf(msg.sender); i++){
            uint256 demand_id = tokenOfOwnerByIndex(msg.sender, i);
            require(_isApprovedOrOwner(msg.sender, demand_id));
            if(!_isOwnBoughtDemand(demand_id) && !_isPurchesed(demand_id)){
                address purchaser = _demands[demand_id].purchaser;
                approve(purchaser, demand_id);
            }
        }
    }
    
    function buyTicket(uint256 demand_id) public payable {
        require(!_isPurchesed(demand_id));
        require(ownerOf(demand_id) != msg.sender);
        require(_demands[demand_id].price == msg.value);
        super._asyncTransfer(ownerOf(demand_id), msg.value);
        _demands[demand_id].price = 0;
        _demands[demand_id].purchaser = msg.sender;
        emit BoughtDemand(demand_id, _demands[demand_id].price);
    }
    
    function getDemandInfo(uint256 demand_id)
        public
        view
        returns(
            bool,
            bool,
            uint256,
            uint256,
            uint256,
            string memory,
            int32,
            int32,
            string memory,
            int32,
            int32
        ){
        Demand memory demand = _demands[demand_id];
        return(
            _isOwnBoughtDemand(demand_id),
            _isPurchesed(demand_id),
            demand.item_id,
            demand.price,
            demand.est_date,
            demand.dept.name,
            demand.dept.latitude,
            demand.dept.longitude,
            demand.arrv.name,
            demand.arrv.latitude,
            demand.arrv.longitude
            );
    }
    
    function _updateDemandToken (
        uint256 item_id,
        uint256 price,
        uint256 est_date,
        string memory dept_name,
        int32 dept_lat,
        int32 dept_lon,
        string memory arrv_name,
        int32 arrv_lat,
        int32 arrv_lon
    )
    private
    {
        for(uint i=0; i< balanceOf(msg.sender); i++){
            uint256 demand_id = tokenOfOwnerByIndex(msg.sender, i);
            require(super._isApprovedOrOwner(msg.sender, demand_id));
            _demands[demand_id].item_id = item_id;
            
            if(price != 0){
                _demands[demand_id].price = price;
                emit ChangeDemand(demand_id, "change price");
            }
            
            if(est_date != 0){
                _demands[demand_id].est_date = est_date;
                emit ChangeDemand(demand_id, "changed estimated time");
            }
            
            if(bytes(dept_name).length!=0 || dept_lat!=0 || dept_lon!=0){
                _demands[demand_id].dept.name = dept_name;
                _demands[demand_id].dept.latitude = dept_lat;
                _demands[demand_id].dept.longitude = dept_lon;
                emit ChangeDemand(demand_id, "changed departure spot");
            }
            
            if(bytes(arrv_name).length!=0 || arrv_lat!=0 || arrv_lon!=0){
                _demands[demand_id].arrv.name = arrv_name;
                _demands[demand_id].arrv.latitude = arrv_lat;
                _demands[demand_id].arrv.longitude = arrv_lon;
                emit ChangeDemand(demand_id, "changed arrival spot");
            }
        }
    }
}
