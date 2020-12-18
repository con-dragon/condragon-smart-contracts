pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";

import "./crcn/CRCN.sol";
import "./SponsorWhitelistControl.sol";

/**
 * @title ConDragon
 * ConDragon - a contract for my semi-fungible tokens.
 */
contract ConDragon is CRCN, IERC777Sender, ReentrancyGuard {
    using Strings for string;

    event UpdateLevel(uint256 id, uint256 level);
    event UpdateCategory(uint256 id, uint256 category);
    event SetControll(address controller, bool permission);

    IERC1820Registry private constant ERC1820_REGISTRY = IERC1820Registry(
        address(0x88887eD889e776bCBe2f0f9932EcFaBcDfCd1820)
    );

    mapping(uint256 => uint256) private category;
    mapping(uint256 => uint256) private level;
    mapping(address => bool) public controller;

    function setController(address _address, bool _allow) public onlyOwner {
        require(_address != address(0), "address can not be empty");
        require(
            controller[_address] != _allow,
            "conDragonNFT:Repeat operation"
        );
        controller[_address] = _allow;
        emit SetControll(_address, _allow);
    }

    modifier onlyController() {
        require(
            isOwner() || controller[msg.sender],
            "conDragon:caller is not the controller"
        );
        _;
    }

    SponsorWhitelistControl public constant SPONSOR = SponsorWhitelistControl(
        address(0x0888000000000000000000000000000000000001)
    );

    constructor(string memory _baseMetadataURI)
        public
        CRCN("conDragon", "conDragon")
    {
        _setBaseMetadataURI(_baseMetadataURI);
        ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            keccak256("ERC777TokensSender"),
            address(this)
        );

        // register all users as sponsees
        address[] memory users = new address[](1);
        users[0] = address(0);
        SPONSOR.addPrivilege(users);
    }

    function setBaseMetadataURI(string memory _newBaseMetadataURI)
        public
        onlyOwner
    {
        _setBaseMetadataURI(_newBaseMetadataURI);
    }

    // IERC777Sender
    function tokensToSend(
        address,
        address from,
        address,
        uint256,
        bytes memory,
        bytes memory
    ) public {
        require(from == address(this), "conDragon: deposit not authorized");
    }

    function uri(uint256 _tokenId) public view returns (string memory) {
        return _getUri(_tokenId);
    }

    function categoryOf(uint256 _tokenId)
        public
        view
        returns (uint256 categoryId)
    {
        if (_exists(_tokenId)) {
            return category[_tokenId];
        } else {
            return 0;
        }
    }

    function levelOf(uint256 _tokenId) public view returns (uint256 levelId) {
        return level[_tokenId];
    }

    function batchCreateNFT(
        address _initialOwner,
        uint256[] calldata _categories,
        uint256 _level,
        uint256 _initialSupply,
        uint256 _cap,
        bytes calldata _data
    ) external onlyController nonReentrant returns (uint256[] memory tokenIds) {
        require(_categories.length <= 7500, "conDragon: Length overflow");
        tokenIds = new uint256[](_categories.length);
        for (uint256 i = 0; i < _categories.length; i++) {
            tokenIds[i] = createNFT(
                _initialOwner,
                _categories[i],
                _level,
                _initialSupply,
                _cap,
                _data
            );
        }
    }

    function batchCreateNFT(
        address[] calldata _initialOwners,
        uint256 _category,
        uint256 _level,
        uint256 _initialSupply,
        uint256 _cap,
        bytes calldata _data
    ) external onlyController nonReentrant returns (uint256[] memory tokenIds) {
        require(_initialOwners.length <= 7500, "conDragon: Length overflow");
        tokenIds = new uint256[](_initialOwners.length);
        for (uint256 i = 0; i < _initialOwners.length; i++) {
            tokenIds[i] = createNFT(
                _initialOwners[i],
                _category,
                _level,
                _initialSupply,
                _cap,
                _data
            );
        }
    }

    function createNFT(
        address _initialOwner,
        uint256 _category,
        uint256 _level,
        uint256 _initialSupply,
        uint256 _cap,
        bytes memory _data
    ) public onlyController returns (uint256 tokenId) {
        require(_category != 0, "conDragon: INVALID_CATEGORY");
        tokenId = create(_initialOwner, _initialSupply, _cap, _data);
        category[tokenId] = _category;
        level[tokenId] = _level;
    }

    function createNFTWithId(
        address _initialOwner,
        uint256 _token_id,
        uint256 _category,
        uint256 _level,
        uint256 _initialSupply,
        uint256 _cap,
        bytes memory _data
    ) public onlyController returns (uint256 tokenId) {
        require(_category != 0, "conDragon: INVALID_CATEGORY");
        tokenId = createWithId(
            _initialOwner,
            _token_id,
            _initialSupply,
            _cap,
            _data
        );
        category[tokenId] = _category;
        level[tokenId] = _level;
    }

    function burnNFT(
        address _from,
        uint256 _id,
        uint256 _amount
    ) external onlyController {
        require(
            (msg.sender == _from) || isApprovedForAll(_from, msg.sender),
            "ERC1155#safeTransferFrom: INVALID_OPERATOR"
        );
        _burn(_from, _id, _amount);
        setRemove(_from, _id);
        delete level[_id];
        delete category[_id];
    }

    function batchBurnNFT(
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external onlyController {
        require(
            (msg.sender == _from) || isApprovedForAll(_from, msg.sender),
            "ERC1155#safeTransferFrom: INVALID_OPERATOR"
        );
        _batchBurn(_from, _ids, _amounts);
        for (uint256 i = 0; i < _ids.length; i++) {
            setRemove(_from, _ids[i]);
            delete level[_ids[i]];
            delete category[_ids[i]];
        }
    }
}
