pragma solidity ^0.4.21;

contract IterableMap {
    struct iterMap {
        address [] index;
        mapping(address => uint256) valuemap;
    }
    
    function add(iterMap storage _itermap, address _address, uint256 _num) internal {
        _itermap.index.push(_address);
        _itermap.valuemap[_address] += _num;
    }
    
    function get(iterMap storage _itermap, address _address) internal returns (uint256) {
        return _itermap.valuemap[_address];
    }
    
    function length(iterMap _itermap) view internal returns (uint) {
        return _itermap.index.length;
    }
    
    function sum(iterMap storage _itermap) internal returns (uint256) {
        uint256 s;
        for (uint i = 0; i < _itermap.index.length; i++) {
            s += _itermap.valuemap[_itermap.index[i]];
        }
        return s;
    }
}

library MatchOutcome {
    enum outcome {
        win, //0
        draw, //1
        lose //2
    }
}

contract Game is IterableMap {
    
    string gameid;
    string gameinfo;

    address bookmaker;
    
    modifier isBookmaker() {
        if (msg.sender != bookmaker) throw;
        _;
    }
    
    struct player {
        address addr;
        bool hasBet;
    }
    
    mapping(address => player) players;
    
    MatchOutcome.outcome realOutcome;
    
    IterableMap.iterMap stakeWin;
    IterableMap.iterMap stakeDraw;
    IterableMap.iterMap stakeLose;
    
    MatchOutcome.outcome win = MatchOutcome.outcome.win;
    MatchOutcome.outcome draw = MatchOutcome.outcome.draw;
    MatchOutcome.outcome lose = MatchOutcome.outcome.lose;

    
    bool isOpen;
    bool isOver = false;

    event LogBet(address _player, MatchOutcome.outcome _outcome);
    event LogSetRealOutcome(MatchOutcome.outcome);
    event LogShareOutBonus(address _player, uint256 _value, bool _success);
    event LogOpen();
    event LogClose();
    
    function Game(string _gameid, string _gameinfo) {
        gameid = _gameid;
        gameinfo = _gameinfo;
        bookmaker = msg.sender;
    }
    
    function getInfo() view returns (string, string) {
        return (gameid, gameinfo);
    }
    
    modifier mustOpen() {
        if (!isOpen) throw;
        _;
    }
    
    modifier mustClose() {
        if (isOpen) throw;
        _;
    }
    
    function open() isBookmaker {
        isOpen = true;
    }
    
    function close() isBookmaker {
        isOpen = false;
    }
    
    function getIsOpen() view returns (bool) {
        return isOpen;
    }
    
    function getIsOver() view returns (bool) {
        return isOver;
    }
    
    function bet(MatchOutcome.outcome _outcome) mustOpen payable {
        require(!players[msg.sender].hasBet);
        require(msg.value > 1000000000000000000);
        if (_outcome == win) {
            IterableMap.add(stakeWin, msg.sender, msg.value);
        }
        if (_outcome == draw) {
            IterableMap.add(stakeDraw, msg.sender, msg.value);
        }
        if (_outcome == lose) {
            IterableMap.add(stakeLose, msg.sender, msg.value);
        }
        players[msg.sender].hasBet = true;
    }
    
    function getTotalStake(MatchOutcome.outcome _outcome) returns (uint256) {
        if (_outcome == win) {
            return IterableMap.sum(stakeWin);
        }
        if (_outcome == draw) {
            return IterableMap.sum(stakeWin);
        }
        if (_outcome == lose) {
            return IterableMap.sum(stakeWin);
        }
    }
    
    function getOutcome() view returns (MatchOutcome.outcome) {
        return realOutcome;
    }

    // bookmaker公布比赛结果
    function setRealOutcome(MatchOutcome.outcome _outcome) mustOpen isBookmaker {
        realOutcome = _outcome;
    }
    
    // bookmaker发放奖励
    function shareOutBonus(MatchOutcome.outcome _outcome) isBookmaker mustClose {
        uint256 totalBonus;
        if (_outcome == win) {
            totalBonus = getTotalStake(draw) + getTotalStake(lose);
        }
        if (_outcome == draw) {
            totalBonus = getTotalStake(win) + getTotalStake(lose);
        }
        if (_outcome == lose) {
            totalBonus = getTotalStake(win) + getTotalStake(draw);
        }
        require(this.balance >= totalBonus);
        uint256 totalstake = getTotalStake(_outcome);
        address player;
        uint256 value;
        if (_outcome == win) {
            for (uint i = 0; i < stakeWin.index.length; i++) {
                player = stakeWin.index[i];
                value = stakeWin.valuemap[player] * totalBonus / totalstake;
                if (!player.send(value)) {
                    LogShareOutBonus(stakeWin.index[i], value, false);
                } else {
                    LogShareOutBonus(stakeWin.index[i], value, true);
                }
            }
        } else if (_outcome == draw) {
            for (uint j = 0; j < stakeDraw.index.length; j++) {
                player = stakeDraw.index[j];
                value = stakeWin.valuemap[player] * totalBonus / totalstake;
                if (!player.send(value)) {
                    LogShareOutBonus(stakeWin.index[i], value, false);
                } else {
                    LogShareOutBonus(stakeWin.index[i], value, true);
                }
            }
        } else if (_outcome == lose) {
            for (uint k = 0; k < stakeLose.index.length; k++) {
                player = stakeLose.index[k];
                value = stakeWin.valuemap[player] * totalBonus / totalstake;
                if (!player.send(value)) {
                    LogShareOutBonus(stakeWin.index[i], value, false);
                } else {
                    LogShareOutBonus(stakeWin.index[i], value, true);
                }
            }
        }
        isOver = true;
    }
    
    function takemoney() isBookmaker {
        if (!isOver) throw;
        bookmaker.send(this.balance);
    }
    
    // bookmaker
    function suicide() isBookmaker external {
        suicide(bookmaker);
    }
}

contract Bookmaker {
    address owner;
    
    event LogNewGame(string _id);
    event LogKillGame(string _id);
    event LogWithdraw();
    
    modifier isOwner {
        require(msg.sender == owner);
        _;
    }
    
    mapping(string => address) games;
    
    function Bookmaker() {
        owner = msg.sender;
    }
    
    function NewGame(string _id, string _gameinfo) isOwner {
        if (games[_id] != 0x0) throw;
        Game game = new Game(_id, _gameinfo);
        games[_id] = game;
        LogNewGame(_id);
    }
    
    function GetContractAddress(string _id) view returns (address) {
        return games[_id];
    }
    
    function Open(string _id) isOwner {
        Game game = Game(games[_id]);
        game.open();
    }
    
    function Close(string _id) isOwner {
        Game game = Game(games[_id]);
        game.close();
    }
    
    function SetRealOutcome(string _id, MatchOutcome.outcome _outcome) isOwner {
        Game game = Game(games[_id]);
        game.setRealOutcome(_outcome);
    }
    
    function ShareOutBonus(string _id) isOwner {
        Game game = Game(games[_id]);
        game.shareOutBonus(game.getOutcome());
    }
    
    function TakeMoney(string _id) isOwner {
        Game game = Game(games[_id]);
        game.takemoney();
    }
    
    function KillGame(string _id) isOwner {
        Game game = Game(games[_id]);
        game.suicide();
        LogKillGame(_id);
    }
    
    function Withdraw() isOwner {
        owner.send(this.balance);
        LogWithdraw();
    }
}
